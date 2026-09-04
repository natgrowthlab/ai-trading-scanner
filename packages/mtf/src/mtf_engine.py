from dataclasses import dataclass
from enum import StrEnum


class Bias(StrEnum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"
    NEUTRAL = "NEUTRAL"


@dataclass(frozen=True)
class TimeframeBias:
    timeframe: str
    bias: Bias
    confidence: int


@dataclass(frozen=True)
class MTFAnalysis:
    macro_bias: Bias
    structure_bias: Bias
    execution_bias: Bias
    alignment_score: int
    aligned: bool


def analyze_mtf(
    macro: TimeframeBias, structure: TimeframeBias, execution: TimeframeBias
) -> MTFAnalysis:
    """Combine H4/H1/setup bias without inventing a directional trade."""
    biases = (macro.bias, structure.bias, execution.bias)
    directional = [bias for bias in biases if bias is not Bias.NEUTRAL]
    common = (
        directional[0]
        if directional and all(bias is directional[0] for bias in directional)
        else Bias.NEUTRAL
    )
    weighted_confidence = (
        macro.confidence * 0.45 + structure.confidence * 0.35 + execution.confidence * 0.2
    )
    alignment = (
        round(weighted_confidence * len(directional) / 3) if common is not Bias.NEUTRAL else 0
    )
    return MTFAnalysis(
        macro.bias, structure.bias, execution.bias, alignment, common is not Bias.NEUTRAL
    )
