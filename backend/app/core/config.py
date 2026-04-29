from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Malinovka Smart Home"
    api_prefix: str = "/api"
    database_url: str = "sqlite:///./malinovka.db"
    public_base_url: str = "http://localhost:8000"
    firmware_version: str = "0.1.0"
    firmware_filename: str = "SmartShev-firmware.bin"
    yandex_oauth_client_id: str = "malinovka-yandex"
    yandex_oauth_client_secret: str = "change-me"
    yandex_oauth_code: str = "malinovka-auth-code"
    yandex_oauth_token: str = "malinovka-dev-token"
    yandex_user_id: str = "malinovka-local-user"

    model_config = SettingsConfigDict(env_prefix="MALINOVKA_", env_file=".env", extra="ignore")

    @property
    def project_root(self) -> Path:
        return Path(__file__).resolve().parents[3]

    @property
    def device_images_dir(self) -> Path:
        return self.project_root / "images"

    @property
    def firmware_dir(self) -> Path:
        return self.project_root / "firmware"


@lru_cache
def get_settings() -> Settings:
    return Settings()
