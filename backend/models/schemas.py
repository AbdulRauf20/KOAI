from pydantic import BaseModel, Field, field_validator


class QuestionRequest(BaseModel):
    question: str = Field(min_length=3, max_length=1000)
    options: list[str] = Field(min_length=2, max_length=6)

    @field_validator("options")
    @classmethod
    def options_must_be_non_empty(cls, options: list[str]) -> list[str]:
        cleaned = [opt.strip() for opt in options]
        if any(not opt for opt in cleaned):
            raise ValueError("every option must be a non-empty string")
        return cleaned


class LatencyMetrics(BaseModel):
    ai_ms: int
    server_total_ms: int


class AnswerResponse(BaseModel):
    answer: str  # "A".."F"
    confidence: float = Field(ge=0.0, le=1.0)
    metrics: LatencyMetrics
