import logging
import time

from models.schemas import AnswerResponse, LatencyMetrics, QuestionRequest
from providers.base import AIProvider

logger = logging.getLogger("koai")


async def answer_question(request: QuestionRequest, provider: AIProvider) -> AnswerResponse:
    server_start = time.perf_counter()

    logger.info("Received question: %.60s...", request.question)

    ai_start = time.perf_counter()
    result = await provider.answer_question(request.question, request.options)
    ai_ms = int((time.perf_counter() - ai_start) * 1000)

    logger.info("AI answered %s (confidence %.2f) in %d ms",
                result["answer"], result["confidence"], ai_ms)

    return AnswerResponse(
        answer=result["answer"],
        confidence=result["confidence"],
        metrics=LatencyMetrics(
            ai_ms=ai_ms,
            server_total_ms=int((time.perf_counter() - server_start) * 1000),
        ),
    )