"""Deterministic, provider-neutral market intelligence orchestration.

All timestamps are UTC; session classification converts only for exchange/session rules.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime
from statistics import mean
from zoneinfo import ZoneInfo

from app.services.market_data import CandleData

SUPPORTED_MARKETS = ("NQ", "ES", "YM", "RTY", "GC")
SUPPORTED_TIMEFRAMES = {"1m", "3m", "5m", "15m", "30m", "1h", "4h", "1D", "1W"}


@dataclass(frozen=True)
class SessionLevel:
    type: str
    price: float
    timestamp: datetime
    state: str = "UNTOUCHED"


@dataclass(frozen=True)
class IntelligenceConfig:
    pivot_left: int = 3
    pivot_right: int = 3
    equal_tolerance_atr: float = 0.15
    minimum_confidence: int = 65
    account_balance: float = 10_000
    risk_percent: float = 1.0


INSTRUMENTS = {
    "NQ": {"tick_size": 0.25, "tick_value": 5.0, "max_contracts": 10},
    "ES": {"tick_size": 0.25, "tick_value": 12.5, "max_contracts": 10},
    "YM": {"tick_size": 1.0, "tick_value": 5.0, "max_contracts": 10},
    "RTY": {"tick_size": 0.1, "tick_value": 5.0, "max_contracts": 10},
    "GC": {"tick_size": 0.1, "tick_value": 10.0, "max_contracts": 10},
}


def _value(candle: CandleData, field: str) -> float:
    return float(getattr(candle, field))


def _atr(candles: list[CandleData], index: int, period: int = 14) -> float:
    start = max(0, index - period + 1)
    return max(mean(_value(item, "high") - _value(item, "low") for item in candles[start : index + 1]), 1e-9)


def _session_name(timestamp: datetime) -> str:
    local = timestamp.astimezone(ZoneInfo("America/New_York"))
    minute = local.hour * 60 + local.minute
    if 9 * 60 + 30 <= minute < 11 * 60 + 30:
        return "NY_AM"
    if 11 * 60 + 30 <= minute < 13 * 60 + 30:
        return "LUNCH"
    if 13 * 60 + 30 <= minute < 15 * 60 + 30:
        return "NY_PM"
    if 4 * 60 <= minute < 9 * 60 + 30:
        return "PREMARKET"
    return "AFTER_HOURS"


def session_levels(candles: list[CandleData]) -> list[SessionLevel]:
    """Previous day/week plus Asia, London and overnight levels without browser timezone."""
    if not candles:
        return []
    et = ZoneInfo("America/New_York")
    groups: dict[str, list[CandleData]] = {"ASIA": [], "LONDON": [], "OVERNIGHT": []}
    by_day: dict[object, list[CandleData]] = {}
    by_week: dict[tuple[int, int], list[CandleData]] = {}
    for candle in candles:
        local = candle.timestamp.astimezone(et)
        minute = local.hour * 60 + local.minute
        if minute < 4 * 60:
            groups["ASIA"].append(candle)
        if 2 * 60 <= minute < 5 * 60:
            groups["LONDON"].append(candle)
        if minute >= 18 * 60 or minute < 9 * 60 + 30:
            groups["OVERNIGHT"].append(candle)
        by_day.setdefault(local.date(), []).append(candle)
        iso = local.isocalendar()
        by_week.setdefault((iso.year, iso.week), []).append(candle)
    result: list[SessionLevel] = []
    for name, group in groups.items():
        if group:
            result.extend((
                SessionLevel(f"{name}_HIGH", max(_value(c, "high") for c in group), group[-1].timestamp),
                SessionLevel(f"{name}_LOW", min(_value(c, "low") for c in group), group[-1].timestamp),
            ))
    days = sorted(by_day)
    if len(days) >= 2:
        previous = by_day[days[-2]]
        result.extend((
            SessionLevel("PDH", max(_value(c, "high") for c in previous), previous[-1].timestamp),
            SessionLevel("PDL", min(_value(c, "low") for c in previous), previous[-1].timestamp),
            SessionLevel("PDC", _value(previous[-1], "close"), previous[-1].timestamp),
        ))
    weeks = sorted(by_week)
    if len(weeks) >= 2:
        previous = by_week[weeks[-2]]
        result.extend((
            SessionLevel("PWH", max(_value(c, "high") for c in previous), previous[-1].timestamp),
            SessionLevel("PWL", min(_value(c, "low") for c in previous), previous[-1].timestamp),
            SessionLevel("PWC", _value(previous[-1], "close"), previous[-1].timestamp),
        ))
    return result


def _swings(candles: list[CandleData], left: int, right: int) -> list[dict[str, object]]:
    swings: list[dict[str, object]] = []
    for index in range(left, len(candles) - right):
        window = candles[index - left : index + right + 1]
        current = candles[index]
        if _value(current, "high") == max(_value(c, "high") for c in window):
            swings.append({"type": "HIGH", "price": _value(current, "high"), "timestamp": current.timestamp, "confirmedAt": candles[index + right].timestamp})
        if _value(current, "low") == min(_value(c, "low") for c in window):
            swings.append({"type": "LOW", "price": _value(current, "low"), "timestamp": current.timestamp, "confirmedAt": candles[index + right].timestamp})
    return swings


def _structure(candles: list[CandleData], config: IntelligenceConfig) -> dict[str, object]:
    swings = _swings(candles, config.pivot_left, config.pivot_right)
    highs = [s for s in swings if s["type"] == "HIGH"]
    lows = [s for s in swings if s["type"] == "LOW"]
    trend = "NEUTRAL"
    if len(highs) >= 2 and len(lows) >= 2:
        bullish = highs[-1]["price"] > highs[-2]["price"] and lows[-1]["price"] > lows[-2]["price"]
        bearish = highs[-1]["price"] < highs[-2]["price"] and lows[-1]["price"] < lows[-2]["price"]
        trend = "BULLISH" if bullish else "BEARISH" if bearish else "NEUTRAL"
    events: list[dict[str, object]] = []
    if candles and highs and _value(candles[-1], "close") > highs[-1]["price"]:
        events.append({"type": "BOS", "direction": "BULLISH", "brokenLevel": highs[-1]["price"], "timestamp": candles[-1].timestamp})
    if candles and lows and _value(candles[-1], "close") < lows[-1]["price"]:
        events.append({"type": "BOS", "direction": "BEARISH", "brokenLevel": lows[-1]["price"], "timestamp": candles[-1].timestamp})
    return {"trend": trend, "swings": swings[-20:], "events": events}


def _liquidity(candles: list[CandleData], levels: list[SessionLevel], config: IntelligenceConfig) -> list[dict[str, object]]:
    result = [asdict(level) | {"id": f"{level.type}-{level.timestamp.isoformat()}", "importanceScore": 80 if level.type.startswith("P") else 60, "touches": 0, "swept": False} for level in levels]
    for swing in _swings(candles, config.pivot_left, config.pivot_right):
        result.append({"id": f"SWING_{swing['type']}-{swing['timestamp'].isoformat()}", "type": f"SWING_{swing['type']}", "price": swing["price"], "timestamp": swing["timestamp"], "state": "UNTOUCHED", "importanceScore": 50, "touches": 0, "swept": False})
    for index, candle in enumerate(candles):
        tolerance = _atr(candles, index) * config.equal_tolerance_atr
        for prior in candles[:index]:
            if abs(_value(candle, "high") - _value(prior, "high")) <= tolerance:
                result.append({"id": f"EQH-{prior.timestamp.isoformat()}", "type": "EQUAL_HIGH", "price": _value(prior, "high"), "timestamp": prior.timestamp, "state": "TESTED", "importanceScore": 65, "touches": 2, "swept": False})
                break
    return result[-100:]


def _fvg(candles: list[CandleData]) -> list[dict[str, object]]:
    gaps: list[dict[str, object]] = []
    for index in range(2, len(candles)):
        first, _, third = candles[index - 2 : index + 1]
        if _value(first, "high") < _value(third, "low"):
            gaps.append({"direction": "BULLISH", "upperPrice": _value(third, "low"), "lowerPrice": _value(first, "high"), "createdAt": third.timestamp, "mitigated": False})
        elif _value(first, "low") > _value(third, "high"):
            gaps.append({"direction": "BEARISH", "upperPrice": _value(first, "low"), "lowerPrice": _value(third, "high"), "createdAt": third.timestamp, "mitigated": False})
    return gaps[-20:]


def _sweeps(candles: list[CandleData], liquidity: list[dict[str, object]]) -> list[dict[str, object]]:
    if not candles:
        return []
    candle = candles[-1]
    output = []
    for level in liquidity:
        price = float(level["price"])
        if "LOW" in str(level["type"]) and _value(candle, "low") < price < _value(candle, "close"):
            output.append({"direction": "BULLISH", "liquidityLevelId": level["id"], "sweptPrice": price, "reclaimed": True, "candleTimestamp": candle.timestamp, "qualityScore": 60})
        if "HIGH" in str(level["type"]) and _value(candle, "high") > price > _value(candle, "close"):
            output.append({"direction": "BEARISH", "liquidityLevelId": level["id"], "sweptPrice": price, "reclaimed": True, "candleTimestamp": candle.timestamp, "qualityScore": 60})
    return output


def _risk(symbol: str, direction: str, entry: float, stop: float, config: IntelligenceConfig) -> dict[str, float | int]:
    instrument = INSTRUMENTS[symbol]
    risk_usd = config.account_balance * config.risk_percent / 100
    per_contract = abs(entry - stop) / instrument["tick_size"] * instrument["tick_value"]
    contracts = min(instrument["max_contracts"], int(risk_usd // per_contract)) if per_contract else 0
    return {"riskUSD": round(risk_usd, 2), "stopDistance": round(abs(entry - stop), 4), "contracts": contracts, "maxLoss": round(contracts * per_contract, 2)}


def evaluate_prop_firm(account_size: float, current_balance: float, max_daily_loss: float, max_total_loss: float, daily_loss: float, total_drawdown: float) -> dict[str, object]:
    daily_remaining = max(0.0, max_daily_loss - daily_loss)
    drawdown_remaining = max(0.0, max_total_loss - total_drawdown)
    consumed = max(1 - daily_remaining / max_daily_loss if max_daily_loss else 1, 1 - drawdown_remaining / max_total_loss if max_total_loss else 1)
    multiplier = 1.0 if consumed < .25 else .75 if consumed < .5 else .5 if consumed < .75 else .25
    status = "LOCKED" if min(daily_remaining, drawdown_remaining) <= 0 else "DANGER" if consumed >= .75 else "CAUTION" if consumed >= .5 else "SAFE"
    return {"currentEquity": current_balance, "dailyLossRemaining": daily_remaining, "drawdownRemaining": drawdown_remaining, "riskMultiplier": multiplier, "maximumSafeRisk": round(account_size * .01 * multiplier, 2), "status": status}


def analyze_market(symbol: str, timeframe: str, candles: list[CandleData], config: IntelligenceConfig = IntelligenceConfig()) -> dict[str, object]:
    if symbol not in SUPPORTED_MARKETS:
        raise ValueError(f"unsupported market: {symbol}")
    if timeframe not in SUPPORTED_TIMEFRAMES:
        raise ValueError(f"unsupported timeframe: {timeframe}")
    levels = session_levels(candles)
    structure = _structure(candles, config)
    liquidity = _liquidity(candles, levels, config)
    sweeps = _sweeps(candles, liquidity)
    gaps = _fvg(candles)
    last = candles[-1]
    body = abs(_value(last, "close") - _value(last, "open"))
    displacement = min(100, round(body / _atr(candles, len(candles) - 1) * 50))
    bullish = 50 + (20 if structure["trend"] == "BULLISH" else -20 if structure["trend"] == "BEARISH" else 0) + (10 if _value(last, "close") > _value(last, "open") else -10)
    bias_score = max(0, min(100, bullish))
    direction = "BULLISH" if bias_score >= 60 else "BEARISH" if bias_score <= 40 else "NEUTRAL"
    matching = [s for s in sweeps if s["direction"] == direction]
    gap_match = any(g["direction"] == direction for g in gaps)
    confirmations = {"dailyBias": 15 if direction != "NEUTRAL" else 0, "liquiditySweep": 20 if matching else 0, "structure": 15 if structure["events"] else 0, "displacement": 10 if displacement >= 50 else 0, "fvg": 10 if gap_match else 0, "session": 10 if _session_name(last.timestamp) in {"NY_AM", "NY_PM"} else 3, "riskReward": 5}
    confidence = sum(confirmations.values())
    setup = None
    if matching and structure["events"] and gap_match and confidence >= config.minimum_confidence:
        trade_direction = "LONG" if direction == "BULLISH" else "SHORT"
        stop = min(_value(last, "low"), min(float(x["price"]) for x in liquidity if "LOW" in str(x["type"]))) if trade_direction == "LONG" else max(_value(last, "high"), max(float(x["price"]) for x in liquidity if "HIGH" in str(x["type"])))
        distance = abs(_value(last, "close") - stop)
        targets = [_value(last, "close") + distance * multiplier if trade_direction == "LONG" else _value(last, "close") - distance * multiplier for multiplier in (1, 2, 3)]
        setup = {"id": f"{symbol}-{last.timestamp.isoformat()}", "direction": trade_direction, "status": "CONFIRMED", "preferredEntry": _value(last, "close"), "entryZone": {"low": _value(last, "close"), "high": _value(last, "close")}, "stopLoss": stop, "targets": targets, "riskReward": 3, "confidence": confidence, "confirmations": confirmations, "risk": _risk(symbol, trade_direction, _value(last, "close"), stop, config)}
    return {"symbol": symbol, "timeframe": timeframe, "dataStatus": "MOCK", "currentPrice": _value(last, "close"), "session": _session_name(last.timestamp), "levels": [asdict(x) for x in levels], "liquidity": liquidity, "structure": structure, "sweeps": sweeps, "fvg": gaps, "smt": {"status": "UNAVAILABLE", "reason": "comparison candles not supplied"}, "displacement": {"score": displacement}, "bias": {"direction": direction, "score": bias_score, "reasons": ["confirmed structure", "latest candle direction"]}, "confidence": {"score": confidence, "components": confirmations}, "setup": setup}
