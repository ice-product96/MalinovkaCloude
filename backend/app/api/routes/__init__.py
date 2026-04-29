from app.api.routes.catalog import router as catalog_router
from app.api.routes.config import router as config_router
from app.api.routes.devices import router as devices_router
from app.api.routes.rooms import router as rooms_router
from app.api.routes.yandex import oauth_router as yandex_oauth_router
from app.api.routes.yandex import router as yandex_router

__all__ = [
    "catalog_router",
    "config_router",
    "devices_router",
    "rooms_router",
    "yandex_oauth_router",
    "yandex_router",
]
