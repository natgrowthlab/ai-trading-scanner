from sqlalchemy import select

from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.market import Asset, AssetClass


def seed_assets() -> None:
    Base.metadata.create_all(bind=engine)
    assets = [
        ("XAUUSD", "Gold / US Dollar", AssetClass.METAL),
        ("NAS100", "Nasdaq 100", AssetClass.INDEX),
        ("BTCUSDT", "Bitcoin / Tether", AssetClass.CRYPTO),
    ]
    with SessionLocal() as db:
        for symbol, display_name, asset_class in assets:
            if db.scalar(select(Asset).where(Asset.symbol == symbol)) is None:
                db.add(Asset(symbol=symbol, display_name=display_name, asset_class=asset_class))
        db.commit()


if __name__ == "__main__":
    seed_assets()
