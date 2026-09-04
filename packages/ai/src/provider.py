from abc import ABC, abstractmethod
from typing import Any


class AIProvider(ABC):
    """Optional explanation layer. Implementations must never create or alter a trade plan."""

    @abstractmethod
    async def analyze_trade(self, signal: dict[str, Any]) -> dict[str, Any]: ...

    @abstractmethod
    async def summarize_market(self, context: dict[str, Any]) -> dict[str, Any]: ...

    @abstractmethod
    async def explain_signal(self, signal: dict[str, Any]) -> dict[str, Any]: ...
