from fastapi.testclient import TestClient

from main import app, get_provider
from providers.base import AIProvider, AIProviderError, AIProviderTimeout


class FakeProvider(AIProvider):
    async def answer_question(self, question, options):
        return {"answer": "C", "confidence": 0.9}


class TimeoutProvider(AIProvider):
    async def answer_question(self, question, options):
        raise AIProviderTimeout("simulated")


class BrokenProvider(AIProvider):
    async def answer_question(self, question, options):
        raise AIProviderError("simulated provider failure")


VALID_BODY = {
    "question": "Which protocol is connection-oriented?",
    "options": ["UDP", "IP", "TCP", "ICMP"],
}


def make_client(provider):
    app.dependency_overrides[get_provider] = lambda: provider
    return TestClient(app)


def teardown_function():
    app.dependency_overrides.clear()


def test_home():
    response = TestClient(app).get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "KOAI Backend is running!"}


def test_answer_success():
    response = make_client(FakeProvider()).post("/answer", json=VALID_BODY)
    assert response.status_code == 200
    body = response.json()
    assert body["answer"] == "C"
    assert body["confidence"] == 0.9
    assert "ai_ms" in body["metrics"]
    assert "server_total_ms" in body["metrics"]


def test_missing_options_rejected():
    response = make_client(FakeProvider()).post(
        "/answer", json={"question": "Hi there?"}
    )
    assert response.status_code == 422


def test_empty_options_rejected():
    response = make_client(FakeProvider()).post(
        "/answer", json={"question": "Hi there?", "options": []}
    )
    assert response.status_code == 422


def test_blank_option_rejected():
    response = make_client(FakeProvider()).post(
        "/answer", json={"question": "Hi there?", "options": ["TCP", "  "]}
    )
    assert response.status_code == 422


def test_too_many_options_rejected():
    response = make_client(FakeProvider()).post(
        "/answer", json={"question": "Hi there?", "options": ["a"] * 7}
    )
    assert response.status_code == 422


def test_provider_timeout_returns_504():
    response = make_client(TimeoutProvider()).post("/answer", json=VALID_BODY)
    assert response.status_code == 504
    assert response.json() == {"error": "AI provider timeout"}


def test_provider_error_returns_502():
    response = make_client(BrokenProvider()).post("/answer", json=VALID_BODY)
    assert response.status_code == 502
    assert response.json() == {"error": "AI provider error"}
