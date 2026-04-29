from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AppSetting, CookingProgram, DeviceCommand, DeviceType, Room, User


SMART_SHEV_ID = "smart_shev_autoclave"

SMART_SHEV_BLE_PROFILE = {
    "scan_name_prefix": "MALINOVKA_",
    "service_uuid": "0000180a-0000-1000-8000-34865d4e5be2",
    "characteristics": {
        "state": "00002b0d-0000-1000-8000-00805f9b34fb",
        "status": "00002b05-0000-1000-8000-00805f9b34fb",
        "heat": "00002b18-0000-1000-8000-00805f9b34fb",
        "end": "00002b44-0000-1000-8000-00805f9b34fb",
        "write": "00002b45-0000-1000-8000-00805f9b34fb",
    },
    "state_keys": [
        "temperature",
        "settemperature",
        "status",
        "timeend",
        "settimeend",
        "load",
        "modeSmoke",
        "nameprog",
        "id",
    ],
}

SMART_SHEV_CAPABILITIES = {
    "device_kind": "autoclave",
    "max_temperature_celsius": 120,
    "max_duration_minutes": 120,
    "modes": [
        {"name": "На воде", "code": 0},
        {"name": "На пару", "code": 1},
        {"name": "Ретро-пакет", "code": 2},
        {"name": "Су-вид", "code": 3},
    ],
    "volume_groups": ["до 0,35л", "от 0,35л до 1л", "от 1л"],
}

SMART_SHEV_COMMANDS = [
    {
        "name": "set_server",
        "transport": "ble",
        "template": "setuid;S45S72;{server_url};",
        "description": "Передает устройству полный URL FastAPI link endpoint.",
        "schema": {"required": ["server_url"]},
    },
    {
        "name": "set_wifi",
        "transport": "ble",
        "template": "setwifi;{ssid};{password};",
        "description": "Передает Wi-Fi SSID и пароль через BLE.",
        "schema": {"required": ["ssid", "password"]},
    },
    {
        "name": "start_program",
        "transport": "ble_or_cloud",
        "template": "work;{hours};{minutes};{temperature};{mode_code};{name};",
        "description": "Запускает программу приготовления.",
        "schema": {"required": ["hours", "minutes", "temperature", "mode_code", "name"]},
    },
    {
        "name": "stop",
        "transport": "ble_or_cloud",
        "template": "stop;",
        "description": "Останавливает текущую программу.",
        "schema": {},
    },
    {
        "name": "set_time",
        "transport": "ble",
        "template": "settime;{hours};{minutes};",
        "description": "Устанавливает часы устройства.",
        "schema": {"required": ["hours", "minutes"]},
    },
]

SMART_SHEV_PROGRAMS = [
    ("Говядина тушеная", "На воде", "от 1л", "Мясо", 90, 115, 0),
    ("Курица в банке", "На воде", "от 0,35л до 1л", "Птица", 55, 112, 0),
    ("Овощное рагу", "На воде", "до 0,35л", "Овощи", 35, 105, 0),
    ("Рыба на пару", "На пару", "до 0,35л", "Рыба", 25, 98, 1),
    ("Котлеты на пару", "На пару", "от 0,35л до 1л", "Мясо", 40, 100, 1),
    ("Свинина ретро", "Ретро-пакет", "от 1л", "Мясо", 100, 118, 2),
    ("Грибы ретро", "Ретро-пакет", "от 0,35л до 1л", "Закуски", 45, 108, 2),
    ("Стейк су-вид", "Су-вид", "от 0,35л до 1л", "Мясо", 120, 58, 3),
    ("Индейка су-вид", "Су-вид", "от 1л", "Птица", 110, 64, 3),
    ("Яйцо су-вид", "Су-вид", "до 0,35л", "Завтрак", 45, 63, 3),
]


def seed_database(db: Session) -> None:
    user = db.get(User, 1)
    if user is None:
        user = User(id=1, name="Local user")
        db.add(user)

    if db.scalar(select(Room).limit(1)) is None:
        db.add_all([Room(name="Кухня", user_id=1), Room(name="Гостиная", user_id=1)])

    if db.get(AppSetting, 1) is None:
        db.add(AppSetting(id=1, home_background_url="/static/devices/SmartShev.png"))

    device_type = db.get(DeviceType, SMART_SHEV_ID)
    if device_type is None:
        device_type = DeviceType(
            id=SMART_SHEV_ID,
            display_name="Смарт шеф",
            manufacturer="Malinovka",
            description="Автоклав с BLE-настройкой и Wi-Fi управлением через сервер.",
            image_url="/static/devices/SmartShev.png",
            ble_profile=SMART_SHEV_BLE_PROFILE,
            capabilities=SMART_SHEV_CAPABILITIES,
        )
        db.add(device_type)
        db.flush()

    if not device_type.commands:
        db.add_all([DeviceCommand(device_type_id=SMART_SHEV_ID, **command) for command in SMART_SHEV_COMMANDS])

    if not device_type.cooking_programs:
        db.add_all(
            [
                CookingProgram(
                    device_type_id=SMART_SHEV_ID,
                    name=name,
                    mode=mode,
                    volume_group=volume_group,
                    dish_category=dish_category,
                    duration_minutes=duration,
                    temperature_celsius=temperature,
                    mode_code=mode_code,
                )
                for name, mode, volume_group, dish_category, duration, temperature, mode_code in SMART_SHEV_PROGRAMS
            ]
        )

    db.commit()
