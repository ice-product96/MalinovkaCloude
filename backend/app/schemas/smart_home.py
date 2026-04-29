from typing import Any

from pydantic import BaseModel, Field


class DeviceCommandRead(BaseModel):
    id: int
    name: str
    transport: str
    template: str
    description: str
    parameters_schema: dict[str, Any] = Field(
        default_factory=dict,
        validation_alias="schema",
        serialization_alias="schema",
    )

    model_config = {"from_attributes": True}


class DeviceTypeRead(BaseModel):
    id: str
    display_name: str
    manufacturer: str
    description: str
    image_url: str
    ble_profile: dict[str, Any]
    capabilities: dict[str, Any]
    commands: list[DeviceCommandRead] = []

    model_config = {"from_attributes": True}


class CookingProgramRead(BaseModel):
    id: int
    name: str
    mode: str
    volume_group: str
    dish_category: str
    duration_minutes: int
    temperature_celsius: int
    mode_code: int

    model_config = {"from_attributes": True}


class UserCookingProgramCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    mode: str = Field(min_length=1, max_length=80)
    volume_group: str = "Пользовательская"
    dish_category: str = "Мои программы"
    duration_minutes: int = Field(ge=0, le=120)
    temperature_celsius: int = Field(ge=0, le=120)
    mode_code: int = Field(ge=0, le=3)


class UserCookingProgramRead(CookingProgramRead):
    user_id: int = 1


class ProgramCategoryGroup(BaseModel):
    category: str
    programs: list[CookingProgramRead]


class ProgramVolumeGroup(BaseModel):
    volume_group: str
    categories: list[ProgramCategoryGroup]


class ProgramModeGroup(BaseModel):
    mode: str
    volumes: list[ProgramVolumeGroup]


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class RoomUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class DeviceRead(BaseModel):
    id: int
    room_id: int
    device_type_id: str
    external_id: str
    name: str
    connection_mode: str
    last_state: dict[str, Any]
    device_type: DeviceTypeRead | None = None

    model_config = {"from_attributes": True}


class RoomRead(BaseModel):
    id: int
    name: str
    devices: list[DeviceRead] = []

    model_config = {"from_attributes": True}


class DeviceCreate(BaseModel):
    room_id: int
    device_type_id: str = "smart_shev_autoclave"
    external_id: str
    name: str = "Смарт шеф"
    connection_mode: str = "ble"


class DeviceUpdate(BaseModel):
    room_id: int | None = None
    name: str | None = Field(default=None, min_length=1, max_length=160)
    connection_mode: str | None = None


class TelemetryIn(BaseModel):
    temperature: str | None = None
    settemperature: str | None = None
    status: str | None = None
    timeend: str | None = None
    settimeend: str | None = None
    load: str | None = None
    modeSmoke: str | None = None
    nameprog: str | None = None
    id: str | None = None

    model_config = {"extra": "allow"}


class CommandRequest(BaseModel):
    name: str
    params: dict[str, Any] = Field(default_factory=dict)


class CommandResponse(BaseModel):
    status: str
    command: str
    payload: dict[str, Any]


class FirmwareInfoRead(BaseModel):
    version: str
    url: str
    update_available: bool | None = None


class AppConfigRead(BaseModel):
    home_background_url: str

    model_config = {"from_attributes": True}


class AppConfigUpdate(BaseModel):
    home_background_url: str = Field(min_length=1, max_length=255)
