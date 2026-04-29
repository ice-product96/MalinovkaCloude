from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import AppSetting
from app.schemas import AppConfigRead

router = APIRouter(prefix="/app-config", tags=["app config"])


def get_or_create_app_setting(db: Session) -> AppSetting:
    setting = db.get(AppSetting, 1)
    if setting is None:
        setting = AppSetting(id=1, home_background_url="/static/devices/SmartShev.png")
        db.add(setting)
        db.commit()
        db.refresh(setting)
    return setting


@router.get("", response_model=AppConfigRead)
def read_app_config(db: Session = Depends(get_db)) -> AppSetting:
    return get_or_create_app_setting(db)
