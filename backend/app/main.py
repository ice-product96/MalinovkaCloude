from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import catalog_router, config_router, devices_router, rooms_router
from app.core.config import get_settings
from app.db import SessionLocal, engine
from app.db.seed import seed_database
from app.db.session import Base
from app import models as _models  # noqa: F401


settings = get_settings()


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    if settings.device_images_dir.exists():
        app.mount("/static/devices", StaticFiles(directory=settings.device_images_dir), name="device-images")
    if settings.firmware_dir.exists():
        app.mount("/static/firmware", StaticFiles(directory=settings.firmware_dir), name="firmware")

    app.include_router(catalog_router, prefix=settings.api_prefix)
    app.include_router(config_router, prefix=settings.api_prefix)
    app.include_router(rooms_router, prefix=settings.api_prefix)
    app.include_router(devices_router, prefix=settings.api_prefix)

    @app.on_event("startup")
    def on_startup() -> None:
        Base.metadata.create_all(bind=engine)
        with SessionLocal() as db:
            seed_database(db)

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
