from abc import ABC, abstractmethod


class AIProviderError(Exception):
    """The provider failed (network, rate limit, malformed response)."""


class AIProviderTimeout(AIProviderError):
    """The provider took too long."""


class AIProvider(ABC):
    @abstractmethod
    async def answer_question(self, question: str, options: list[str]) -> dict:
        """
        Return {"answer": "<letter>", "confidence": <float 0..1>}.
        Raise AIProviderError / AIProviderTimeout on failure.
        """