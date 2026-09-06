from fastapi import APIRouter, HTTPException, Query
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field

from app.services.intelligence import SUPPORTED_MARKETS, SUPPORTED_TIMEFRAMES, analyze_market, evaluate_prop_firm
from app.services.market_data import MockMarketDataProvider

router = APIRouter(tags=["market-intelligence"])
provider = MockMarketDataProvider()


async def _analysis(symbol: str, timeframe: str) -> dict:
    symbol = symbol.upper()
    if symbol not in SUPPORTED_MARKETS:
        raise HTTPException(status_code=404, detail=f"Unsupported market. Use: {', '.join(SUPPORTED_MARKETS)}")
    if timeframe not in SUPPORTED_TIMEFRAMES:
        raise HTTPException(status_code=422, detail="Unsupported timeframe")
    return analyze_market(symbol, timeframe, await provider.get_candles(symbol, timeframe, 300))


@router.get("/scanner")
async def scanner(timeframe: str = Query("5m")) -> list[dict]:
    return jsonable_encoder([await _analysis(symbol, timeframe) for symbol in SUPPORTED_MARKETS])


@router.get("/markets/{symbol}")
async def market_detail(symbol: str, timeframe: str = Query("5m")) -> dict:
    return jsonable_encoder(await _analysis(symbol, timeframe))


@router.get("/markets/{symbol}/{section}")
async def market_section(symbol: str, section: str, timeframe: str = Query("5m")) -> object:
    analysis = await _analysis(symbol, timeframe)
    aliases = {"bias": "bias", "liquidity": "liquidity", "structure": "structure", "sweeps": "sweeps", "fvg": "fvg", "smt": "smt", "setups": "setup"}
    if section not in aliases:
        raise HTTPException(status_code=404, detail="Unknown market intelligence section")
    return jsonable_encoder(analysis[aliases[section]])


class PropRiskRequest(BaseModel):
    account_size: float = Field(gt=0)
    current_balance: float = Field(gt=0)
    max_daily_loss: float = Field(gt=0)
    max_total_loss: float = Field(gt=0)
    daily_loss: float = Field(ge=0)
    total_drawdown: float = Field(ge=0)


@router.post("/prop-accounts/evaluate")
def prop_risk(payload: PropRiskRequest) -> dict:
    return evaluate_prop_firm(**payload.model_dump())
