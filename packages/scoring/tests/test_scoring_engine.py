import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from scoring_engine import ScoreClassification, ScoreComponent, calculate_score


def test_weighted_score_classifies_strong_signal():
    result = calculate_score(
        [
            ScoreComponent("structure", 1),
            ScoreComponent("liquidity", 1),
            ScoreComponent("mtf", 1),
            ScoreComponent("order_block", 1),
            ScoreComponent("fvg", 1),
            ScoreComponent("momentum", 1),
            ScoreComponent("volume", 1),
            ScoreComponent("session", 1),
            ScoreComponent("volatility", 0.6),
        ]
    )
    assert result.score == 98
    assert result.classification is ScoreClassification.A_PLUS
    assert result.eligible
