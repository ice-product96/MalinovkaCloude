from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.orm.attributes import flag_modified

from app.core.config import get_settings
from app.db import get_db
from app.models import Device, DeviceCommand, DeviceType, Room, TelemetryEvent
from app.schemas import CommandRequest, CommandResponse, DeviceCreate, DeviceRead, DeviceUpdate, FirmwareInfoRead, TelemetryIn

router = APIRouter(tags=["devices"])


def _render_template(template: str, params: dict[str, Any]) -> str:
    try:
        return template.format(**params)
    except KeyError as exc:
        raise HTTPException(status_code=422, detail=f"Missing command parameter: {exc.args[0]}") from exc


def _firmware_payload(command_name: str, params: dict[str, Any]) -> dict[str, Any]:
    if command_name == "start_program":
        duration = int(params.get("duration_minutes", 0))
        hours = int(params.get("hours", duration // 60))
        minutes = int(params.get("minutes", duration % 60))
        return {
            "status": "work",
            "mode": int(params["mode_code"]),
            "temperature": int(params["temperature"]),
            "hours": hours,
            "minutes": minutes,
            "name": str(params["name"]),
        }
    if command_name == "stop":
        return {"status": "stop"}
    return {"status": "idle"}


def _version_tuple(version: str) -> tuple[int, ...]:
    parts: list[int] = []
    for part in version.replace("-", ".").split("."):
        number = ""
        for char in part:
            if char.isdigit():
                number += char
            else:
                break
        parts.append(int(number or 0))
    return tuple(parts)


def _is_idle_for_update(device: Device) -> bool:
    status = str((device.last_state or {}).get("status", "")).strip().lower()
    if any(value in status for value in ("работ", "нагрев", "разогрев", "продув")):
        return False
    return status in {"", "idle", "wait", "waiting", "ready", "stop", "stopped", "ожидает", "ожидание", "готово", "остановлено"}


def _firmware_url() -> str:
    settings = get_settings()
    return f"{settings.public_base_url}/static/firmware/{settings.firmware_filename}"


@router.get("/devices", response_model=list[DeviceRead])
def list_devices(db: Session = Depends(get_db)) -> list[Device]:
    stmt = select(Device).options(selectinload(Device.device_type).selectinload(DeviceType.commands))
    return list(db.scalars(stmt))


@router.get("/firmware/latest", response_model=FirmwareInfoRead)
def latest_firmware(current_version: str | None = None) -> FirmwareInfoRead:
    settings = get_settings()
    update_available = None
    if current_version:
        update_available = _version_tuple(current_version) < _version_tuple(settings.firmware_version)
    return FirmwareInfoRead(version=settings.firmware_version, url=_firmware_url(), update_available=update_available)


@router.post("/devices", response_model=DeviceRead, status_code=201)
def create_device(payload: DeviceCreate, db: Session = Depends(get_db)) -> Device:
    if db.get(Room, payload.room_id) is None:
        raise HTTPException(status_code=404, detail="Room not found")
    if db.get(DeviceType, payload.device_type_id) is None:
        raise HTTPException(status_code=404, detail="Device type not found")

    device = db.scalar(select(Device).where(Device.external_id == payload.external_id))
    if device is not None:
        device.room_id = payload.room_id
        device.name = payload.name
        device.connection_mode = payload.connection_mode
    else:
        device = Device(**payload.model_dump())
        db.add(device)

    db.commit()
    db.refresh(device)
    return device


@router.get("/devices/{device_id}", response_model=DeviceRead)
def get_device(device_id: int, db: Session = Depends(get_db)) -> Device:
    device = db.scalar(
        select(Device)
        .where(Device.id == device_id)
        .options(selectinload(Device.device_type).selectinload(DeviceType.commands))
    )
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    return device


@router.patch("/devices/{device_id}", response_model=DeviceRead)
def update_device(device_id: int, payload: DeviceUpdate, db: Session = Depends(get_db)) -> Device:
    device = db.scalar(
        select(Device)
        .where(Device.id == device_id)
        .options(selectinload(Device.device_type).selectinload(DeviceType.commands))
    )
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")

    if payload.room_id is not None:
        if db.get(Room, payload.room_id) is None:
            raise HTTPException(status_code=404, detail="Room not found")
        device.room_id = payload.room_id
    if payload.name is not None:
        device.name = payload.name
    if payload.connection_mode is not None:
        device.connection_mode = payload.connection_mode

    db.commit()
    db.refresh(device)
    return device


@router.delete("/devices/{device_id}", status_code=204)
def delete_device(device_id: int, db: Session = Depends(get_db)) -> None:
    device = db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")

    db.delete(device)
    db.commit()


@router.post("/devices/{device_id}/commands", response_model=CommandResponse)
def create_command(device_id: int, payload: CommandRequest, db: Session = Depends(get_db)) -> CommandResponse:
    device = db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")

    command = db.scalar(
        select(DeviceCommand).where(
            DeviceCommand.device_type_id == device.device_type_id,
            DeviceCommand.name == payload.name,
        )
    )
    if command is None:
        raise HTTPException(status_code=404, detail="Command not found")

    params = dict(payload.params)
    if payload.name == "set_server":
        params.setdefault(
            "server_url",
            f"{get_settings().public_base_url}/api/device/link/{device.external_id}",
        )
    if payload.name == "start_program" and "duration_minutes" in params:
        duration = int(params["duration_minutes"])
        params.setdefault("hours", duration // 60)
        params.setdefault("minutes", duration % 60)

    rendered = _render_template(command.template, params)
    firmware_payload = _firmware_payload(payload.name, params)
    device.last_state = {
        **(device.last_state or {}),
        "pending_cloud_command": firmware_payload,
        "last_command": rendered,
    }
    flag_modified(device, "last_state")
    db.commit()

    return CommandResponse(status="queued", command=rendered, payload=firmware_payload)


@router.post("/devices/{device_id}/firmware-update", response_model=CommandResponse)
def request_firmware_update(device_id: int, db: Session = Depends(get_db)) -> CommandResponse:
    device = db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    if device.connection_mode != "wifi":
        raise HTTPException(status_code=409, detail="Firmware update requires Wi-Fi connection")
    if not _is_idle_for_update(device):
        raise HTTPException(status_code=409, detail="Device must be idle before firmware update")

    settings = get_settings()
    current_version = str((device.last_state or {}).get("firmware_version") or (device.last_state or {}).get("version") or "0.0.0")
    if _version_tuple(current_version) >= _version_tuple(settings.firmware_version):
        raise HTTPException(status_code=409, detail="Firmware is already up to date")

    firmware_payload = {
        "status": "ota",
        "url": _firmware_url(),
        "version": settings.firmware_version,
    }
    device.last_state = {
        **(device.last_state or {}),
        "pending_cloud_command": firmware_payload,
        "firmware_update_requested": settings.firmware_version,
    }
    flag_modified(device, "last_state")
    db.commit()
    return CommandResponse(status="queued", command="ota", payload=firmware_payload)


@router.post("/devices/{device_id}/telemetry", response_model=DeviceRead)
def create_telemetry(device_id: int, payload: TelemetryIn, db: Session = Depends(get_db)) -> Device:
    device = db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")

    data = payload.model_dump(exclude_none=True)
    device.last_state = {**(device.last_state or {}), **data}
    flag_modified(device, "last_state")
    db.add(TelemetryEvent(device_id=device.id, payload=data))
    db.commit()
    db.refresh(device)
    return device


@router.post("/device/link/{external_id}")
def firmware_link(external_id: str, payload: TelemetryIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    device = db.scalar(select(Device).where(Device.external_id == external_id))
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")

    data = payload.model_dump(exclude_none=True)
    pending = (device.last_state or {}).pop("pending_cloud_command", None)
    device.last_state = {**(device.last_state or {}), **data}
    flag_modified(device, "last_state")
    db.add(TelemetryEvent(device_id=device.id, payload=data))
    db.commit()
    return pending or {"status": "idle"}
