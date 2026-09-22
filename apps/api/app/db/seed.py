from sqlalchemy import select

from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.market import Asset, AssetClass


def seed_assets() -> None:
    Base.metadata.create_all(bind=engine)
    assets = [
        ("BTCUSDT", "Bitcoin / Tether perpetual", AssetClass.CRYPTO),
        ("ETHUSDT", "Ether / Tether perpetual", AssetClass.CRYPTO),
        ("SOLUSDT", "Solana / Tether perpetual", AssetClass.CRYPTO),
        ("BNBUSDT", "BNB / Tether perpetual", AssetClass.CRYPTO),
        ("XRPUSDT", "XRP / Tether perpetual", AssetClass.CRYPTO),
    ]
    with SessionLocal() as db:
        for symbol, display_name, asset_class in assets:
            if db.scalar(select(Asset).where(Asset.symbol == symbol)) is None:
                db.add(Asset(symbol=symbol, display_name=display_name, asset_class=asset_class))
        db.commit()


if __name__ == "__main__":
    seed_assets()
