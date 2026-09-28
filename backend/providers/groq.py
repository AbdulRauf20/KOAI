import json
import logging
import re

import httpx

from providers.base import AIProvider, AIProviderError, AIProviderTimeout

logger = logging.getLogger("koai")

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

SYSTEM_PROMPT = (
    "You answer multiple-choice questions. "
    'Respond with JSON only, exactly: {"answer": "<letter>", "confidence": <number 0 to 1>}. '
    "Pick exactly one of the given option letters. No explanation."
)


class GroqProvider(AIProvider):
    def __init__(self, api_key: str, model: str, client: httpx.AsyncClient):
        self._api_key = api_key
        self._model = model
        self._client = client  # shared client: reuses TCP+TLS connections

    async def answer_question(self, question: str, options: list[str]) -> dict:
        letters = [chr(ord("A") + i) for i in range(len(options))]
        options_text = "\n".join(f"{l}. {o}" for l, o in zip(letters, options))

        payload = {
            "model": self._model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"{question}\n\n{options_text}"},
            ],
            "temperature": 0,
            "max_completion_tokens": 60,
            "response_format": {"type": "json_object"},
            "reasoning_effort": "low",
        }

        try:
            response = await self._client.post(
                GROQ_URL,
                json=payload,
                headers={"Authorization": f"Bearer {self._api_key}"},
            )
        except httpx.TimeoutException as exc:
            raise AIProviderTimeout("Groq request timed out") from exc
        except httpx.HTTPError as exc:
            raise AIProviderError(f"Network error calling Groq: {exc}") from exc

        if response.status_code == 429:
            raise AIProviderError("Groq rate limit exceeded")
        if response.status_code != 200:
            raise AIProviderError(f"Groq returned HTTP {response.status_code}")

        try:
            content = response.json()["choices"][0]["message"]["content"]
        except (KeyError, IndexError, ValueError) as exc:
            raise AIProviderError("Unexpected Groq response shape") from exc

        return self._parse_model_output(content, letters)

    def _parse_model_output(self, content: str, valid_letters: list[str]) -> dict:
        try:
            data = json.loads(content)
            answer = str(data.get("answer", "")).strip().upper()
            confidence = float(data.get("confidence", 0.5))
        except (json.JSONDecodeError, TypeError, ValueError):
            # Fallback: model ignored JSON mode; look for a lone letter.
            match = re.search(r"\b([A-F])\b", content.upper())
            if not match:
                raise AIProviderError(f"Could not parse model output: {content!r}")
            answer, confidence = match.group(1), 0.5

        if answer not in valid_letters:
            raise AIProviderError(f"Model chose invalid option {answer!r}")

        return {"answer": answer, "confidence": max(0.0, min(1.0, confidence))}