from typing import Literal

from pydantic import BaseModel, Field


class AIAnalysis(BaseModel):
    """Structured explanatory output; not an instruction to trade."""

    verdict: Literal["VALID", "CAUTION", "INVALID"]
    confidence: float = Field(ge=0, le=1)
    summary: str = Field(max_length=1200)
    reasons: list[str] = Field(max_length=10)
    warnings: list[str] = Field(max_length=10)
    market_context: str = Field(max_length=1200)


def validate_analysis(payload: object) -> AIAnalysis:
    return AIAnalysis.model_validate(payload)
