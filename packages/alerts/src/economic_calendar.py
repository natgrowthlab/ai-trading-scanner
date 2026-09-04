from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import StrEnum


class Impact(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


@dataclass(frozen=True)
class EconomicEvent:
    title: str
    timestamp: datetime
    impact: Impact
    currencies: tuple[str, ...] = ()


class EconomicCalendarProvider(ABC):
    @abstractmethod
    async def get_events(self, start: datetime, end: datetime) -> list[EconomicEvent]: ...


@dataclass(frozen=True)
class NewsFilterConfig:
    minutes_before: int = 15
    minutes_after: int = 15
    blocked_impact: Impact = Impact.HIGH


def blocks_signal(
    timestamp: datetime,
    events: list[EconomicEvent],
    config: NewsFilterConfig = NewsFilterConfig(),
) -> bool:
    for event in events:
        if event.impact is not config.blocked_impact:
            continue
        if (
            event.timestamp - timedelta(minutes=config.minutes_before)
            <= timestamp
            <= event.timestamp + timedelta(minutes=config.minutes_after)
        ):
            return True
    return False
