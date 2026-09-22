from fastapi import APIRouter

from app.api.v1.intelligence import router as intelligence_router
from app.api.v1.market import router as market_router
from app.api.v1.signals import router as signals_router

router = APIRouter()
router.include_router(market_router)
router.include_router(intelligence_router)
router.include_router(signals_router)
