from pathlib import Path
import sys

import pytest
from pydantic import ValidationError

sys.path.append(str(Path(__file__).parents[1] / "src"))
from contracts import validate_analysis


def test_requires_strict_structured_ai_output():
    analysis = validate_analysis(
        {
            "verdict": "VALID",
            "confidence": 0.87,
            "summary": "Structure aligns.",
            "reasons": ["BOS"],
            "warnings": [],
            "market_context": "London session.",
        }
    )
    assert analysis.confidence == 0.87
    with pytest.raises(ValidationError):
        validate_analysis(
            {
                "verdict": "VALID",
                "confidence": 2,
                "summary": "",
                "reasons": [],
                "warnings": [],
                "market_context": "",
            }
        )
