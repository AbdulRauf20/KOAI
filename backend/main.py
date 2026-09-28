import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse

from config import settings
from models.schemas import AnswerResponse, QuestionRequest
from providers.base import AIProvider, AIProviderError, AIProviderTimeout
from providers.groq import GroqProvider
from services import ai_engine

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Created once at startup, shared by all requests (warm connections).
    client = httpx.AsyncClient(timeout=settings.ai_timeout_seconds)
    app.state.provider = GroqProvider(settings.groq_api_key, settings.groq_model, client)
    yield
    await client.aclose()


app = FastAPI(title="KOAI Backend", lifespan=lifespan)


def get_provider(request: Request) -> AIProvider:
    return request.app.state.provider


@app.exception_handler(AIProviderTimeout)
async def timeout_handler(request: Request, exc: AIProviderTimeout):
    return JSONResponse(status_code=504, content={"error": "AI provider timeout"})


@app.exception_handler(AIProviderError)
async def provider_error_handler(request: Request, exc: AIProviderError):
    logging.getLogger("koai").error("Provider error: %s", exc)
    return JSONResponse(status_code=502, content={"error": "AI provider error"})


@app.get("/")
def home():
    return {"message": "KOAI Backend is running!"}


@app.post("/answer", response_model=AnswerResponse)
async def answer(data: QuestionRequest, provider: AIProvider = Depends(get_provider)):
    return await ai_engine.answer_question(data, provider)