from fastapi import APIRouter

from app.api.v1.market import router as market_router

router = APIRouter()
router.include_router(market_router)
