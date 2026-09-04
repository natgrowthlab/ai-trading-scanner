from dataclasses import dataclass, field
from enum import StrEnum


class ScoreClassification(StrEnum):
    NO_TRADE = "NO_TRADE"
    WEAK = "WEAK"
    VALID = "VALID"
    STRONG = "STRONG"
    A_PLUS = "A_PLUS"


DEFAULT_WEIGHTS = {
    "structure": 20,
    "liquidity": 15,
    "mtf": 15,
    "order_block": 10,
    "fvg": 10,
    "momentum": 10,
    "volume": 10,
    "session": 5,
    "volatility": 5,
}


@dataclass(frozen=True)
class ScoreComponent:
    name: str
    confidence: float


@dataclass(frozen=True)
class ScoreResult:
    score: int
    classification: ScoreClassification
    eligible: bool
    breakdown: dict[str, float] = field(default_factory=dict)


def calculate_score(
    components: list[ScoreComponent],
    weights: dict[str, float] | None = None,
    min_signal_score: int = 65,
) -> ScoreResult:
    active_weights = weights or DEFAULT_WEIGHTS
    if min_signal_score < 0 or min_signal_score > 100:
        raise ValueError("min_signal_score must be between 0 and 100")
    unknown = {component.name for component in components} - active_weights.keys()
    if unknown:
        raise ValueError(f"unknown score components: {sorted(unknown)}")
    total_weight = sum(active_weights.values())
    if total_weight <= 0:
        raise ValueError("weights must total a positive value")
    normalized = {
        component.name: max(0.0, min(1.0, component.confidence)) for component in components
    }
    breakdown = {
        name: active_weights[name] * normalized.get(name, 0.0) / total_weight * 100
        for name in active_weights
    }
    score = round(sum(breakdown.values()))
    return ScoreResult(score, _classification(score), score >= min_signal_score, breakdown)


def _classification(score: int) -> ScoreClassification:
    if score < 50:
        return ScoreClassification.NO_TRADE
    if score < 65:
        return ScoreClassification.WEAK
    if score < 75:
        return ScoreClassification.VALID
    if score < 85:
        return ScoreClassification.STRONG
    return ScoreClassification.A_PLUS
