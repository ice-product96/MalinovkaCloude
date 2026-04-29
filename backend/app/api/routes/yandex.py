from typing import Any
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, Form, Header, HTTPException, Response, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.orm.attributes import flag_modified

from app.core.config import Settings, get_settings
from app.db import get_db
from app.models import Device, DeviceCommand

router = APIRouter(prefix="/v1.0", tags=["yandex-smart-home"])
oauth_router = APIRouter(prefix="/oauth", tags=["yandex-smart-home-oauth"])


ACTIVE_STATUSES = ("work", "heating", "heat", "smoke", "blow", "cook", "работ", "нагрев", "разогрев", "продув")
IDLE_STATUSES = ("", "idle", "wait", "waiting", "ready", "stop", "stopped", "ожидает", "ожидание", "готово", "останов")


def _request_id(value: str | None) -> str:
    return value or ""


def _normalize_status(device: Device) -> str:
    return str((device.last_state or {}).get("status") or "").strip().lower()


def _is_active(device: Device) -> bool:
    status_value = _normalize_status(device)
    return any(value in status_value for value in ACTIVE_STATUSES)


def _is_online(device: Device) -> bool:
    if device.connection_mode != "wifi":
        return False
    status_value = _normalize_status(device)
    return status_value in IDLE_STATUSES or _is_active(device)


def _temperature(device: Device) -> float:
    raw_value = (device.last_state or {}).get("temperature")
    try:
        return float(str(raw_value).replace(",", "."))
    except (TypeError, ValueError):
        return 0.0


def _firmware_version(device: Device) -> str:
    state = device.last_state or {}
    return str(state.get("firmware_version") or state.get("version") or "unknown")


def _device_capabilities(retrievable: bool = True) -> list[dict[str, Any]]:
    return [
        {
            "type": "devices.capabilities.on_off",
            "retrievable": retrievable,
            "reportable": False,
        }
    ]


def _device_properties() -> list[dict[str, Any]]:
    return [
        {
            "type": "devices.properties.float",
            "retrievable": True,
            "reportable": False,
            "parameters": {
                "instance": "temperature",
                "unit": "unit.temperature.celsius",
            },
        }
    ]


def _capability_state(device: Device) -> list[dict[str, Any]]:
    return [
        {
            "type": "devices.capabilities.on_off",
            "state": {
                "instance": "on",
                "value": _is_active(device),
            },
        }
    ]


def _property_state(device: Device) -> list[dict[str, Any]]:
    return [
        {
            "type": "devices.properties.float",
            "state": {
                "instance": "temperature",
                "value": _temperature(device),
            },
        }
    ]


def _device_response(device: Device) -> dict[str, Any]:
    return {
        "id": str(device.id),
        "name": device.name,
        "status_info": {
            "reportable": True,
        },
        "description": device.device_type.description if device.device_type else "Malinovka Smart Chef",
        "room": device.room.name if device.room else "",
        "type": "devices.types.multicooker",
        "custom_data": {
            "external_id": device.external_id,
        },
        "capabilities": _device_capabilities(),
        "properties": _device_properties(),
        "device_info": {
            "manufacturer": "Malinovka",
            "model": device.device_type.display_name if device.device_type else "Smart Chef",
            "sw_version": _firmware_version(device),
        },
    }


def _authorized_settings(
    authorization: str | None = Header(default=None, alias="Authorization"),
    settings: Settings = Depends(get_settings),
) -> Settings:
    expected = settings.yandex_oauth_token
    token = (authorization or "").removeprefix("Bearer").strip()
    if not expected or token != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authorization token")
    return settings


def _find_device(db: Session, raw_id: Any) -> Device | None:
    try:
        device_id = int(str(raw_id))
    except (TypeError, ValueError):
        return None
    return db.scalar(
        select(Device)
        .where(Device.id == device_id)
        .options(selectinload(Device.device_type), selectinload(Device.room))
    )


def _queue_stop(device: Device, db: Session) -> None:
    command = db.scalar(
        select(DeviceCommand).where(
            DeviceCommand.device_type_id == device.device_type_id,
            DeviceCommand.name == "stop",
        )
    )
    firmware_payload = {"status": "stop"}
    device.last_state = {
        **(device.last_state or {}),
        "pending_cloud_command": firmware_payload,
        "last_command": command.template if command is not None else "stop",
    }
    flag_modified(device, "last_state")


@router.head("")
def check() -> Response:
    return Response(status_code=status.HTTP_200_OK)


@router.get("")
def check_get() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/user/unlink")
def unlink(
    x_request_id: str | None = Header(default=None, alias="X-Request-Id"),
    _: Settings = Depends(_authorized_settings),
) -> dict[str, str]:
    return {"request_id": _request_id(x_request_id)}


@router.get("/user/devices")
def user_devices(
    x_request_id: str | None = Header(default=None, alias="X-Request-Id"),
    settings: Settings = Depends(_authorized_settings),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    stmt = (
        select(Device)
        .where(Device.connection_mode == "wifi")
        .options(selectinload(Device.device_type), selectinload(Device.room))
    )
    devices = [_device_response(device) for device in db.scalars(stmt)]
    return {
        "request_id": _request_id(x_request_id),
        "payload": {
            "user_id": settings.yandex_user_id,
            "devices": devices,
        },
    }


@router.post("/user/devices/query")
def devices_query(
    payload: dict[str, Any],
    x_request_id: str | None = Header(default=None, alias="X-Request-Id"),
    _: Settings = Depends(_authorized_settings),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    devices: list[dict[str, Any]] = []
    for requested in payload.get("devices", []):
        device_id = requested.get("id")
        device = _find_device(db, device_id)
        if device is None:
            devices.append(
                {
                    "id": str(device_id),
                    "error_code": "DEVICE_NOT_FOUND",
                    "error_message": "Device not found",
                }
            )
            continue
        if not _is_online(device):
            devices.append(
                {
                    "id": str(device.id),
                    "error_code": "DEVICE_UNREACHABLE",
                    "error_message": "Device is not connected over Wi-Fi",
                }
            )
            continue
        devices.append(
            {
                "id": str(device.id),
                "capabilities": _capability_state(device),
                "properties": _property_state(device),
            }
        )
    return {"request_id": _request_id(x_request_id), "payload": {"devices": devices}}


@router.post("/user/devices/action")
def devices_action(
    payload: dict[str, Any],
    x_request_id: str | None = Header(default=None, alias="X-Request-Id"),
    _: Settings = Depends(_authorized_settings),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    response_devices: list[dict[str, Any]] = []
    for requested in payload.get("payload", {}).get("devices", []):
        device_id = requested.get("id")
        device = _find_device(db, device_id)
        if device is None:
            response_devices.append(
                {
                    "id": str(device_id),
                    "action_result": {"status": "ERROR", "error_code": "DEVICE_NOT_FOUND"},
                }
            )
            continue
        if not _is_online(device):
            response_devices.append(
                {
                    "id": str(device.id),
                    "action_result": {"status": "ERROR", "error_code": "DEVICE_UNREACHABLE"},
                }
            )
            continue

        capability_results: list[dict[str, Any]] = []
        for capability in requested.get("capabilities", []):
            state = capability.get("state") or {}
            if capability.get("type") != "devices.capabilities.on_off" or state.get("instance") != "on":
                capability_results.append(
                    {
                        "type": capability.get("type", "devices.capabilities.on_off"),
                        "state": {
                            "instance": state.get("instance", "on"),
                            "action_result": {"status": "ERROR", "error_code": "INVALID_ACTION"},
                        },
                    }
                )
                continue

            requested_on = bool(state.get("value"))
            if requested_on:
                capability_results.append(
                    {
                        "type": "devices.capabilities.on_off",
                        "state": {
                            "instance": "on",
                            "action_result": {
                                "status": "ERROR",
                                "error_code": "NOT_SUPPORTED_IN_CURRENT_MODE",
                                "error_message": "Start a cooking program from the Malinovka app.",
                            },
                        },
                    }
                )
                continue

            _queue_stop(device, db)
            capability_results.append(
                {
                    "type": "devices.capabilities.on_off",
                    "state": {"instance": "on", "action_result": {"status": "DONE"}},
                }
            )

        response_devices.append({"id": str(device.id), "capabilities": capability_results})

    db.commit()
    return {"request_id": _request_id(x_request_id), "payload": {"devices": response_devices}}


@oauth_router.get("/authorize")
def oauth_authorize(
    response_type: str,
    client_id: str,
    redirect_uri: str,
    state: str | None = None,
    settings: Settings = Depends(get_settings),
) -> RedirectResponse:
    if response_type != "code" or client_id != settings.yandex_oauth_client_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OAuth request")
    separator = "&" if "?" in redirect_uri else "?"
    query = {"code": settings.yandex_oauth_code}
    if state:
        query["state"] = state
    return RedirectResponse(f"{redirect_uri}{separator}{urlencode(query)}")


@oauth_router.post("/token")
def oauth_token(
    grant_type: str = Form(...),
    code: str = Form(...),
    client_id: str = Form(...),
    client_secret: str = Form(...),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    if (
        grant_type != "authorization_code"
        or code != settings.yandex_oauth_code
        or client_id != settings.yandex_oauth_client_id
        or client_secret != settings.yandex_oauth_client_secret
    ):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OAuth credentials")
    return {
        "access_token": settings.yandex_oauth_token,
        "token_type": "bearer",
        "expires_in": 31536000,
    }
