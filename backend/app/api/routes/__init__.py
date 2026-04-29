from app.api.routes.catalog import router as catalog_router
from app.api.routes.config import router as config_router
from app.api.routes.devices import router as devices_router
from app.api.routes.rooms import router as rooms_router

__all__ = ["catalog_router", "config_router", "devices_router", "rooms_router"]
