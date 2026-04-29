from datetime import datetime
from typing import Any

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120), default="Local user")

    rooms: Mapped[list["Room"]] = relationship(back_populates="user")


class Room(TimestampMixin, Base):
    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), default=1)

    user: Mapped[User] = relationship(back_populates="rooms")
    devices: Mapped[list["Device"]] = relationship(back_populates="room", cascade="all, delete-orphan")


class DeviceType(TimestampMixin, Base):
    __tablename__ = "device_types"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(160))
    manufacturer: Mapped[str] = mapped_column(String(120), default="Malinovka")
    description: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str] = mapped_column(String(255))
    ble_profile: Mapped[dict[str, Any]] = mapped_column(JSON)
    capabilities: Mapped[dict[str, Any]] = mapped_column(JSON)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    commands: Mapped[list["DeviceCommand"]] = relationship(back_populates="device_type", cascade="all, delete-orphan")
    cooking_programs: Mapped[list["CookingProgram"]] = relationship(
        back_populates="device_type", cascade="all, delete-orphan"
    )
    devices: Mapped[list["Device"]] = relationship(back_populates="device_type")


class DeviceCommand(TimestampMixin, Base):
    __tablename__ = "device_commands"
    __table_args__ = (UniqueConstraint("device_type_id", "name", name="uq_device_command_type_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    device_type_id: Mapped[str] = mapped_column(ForeignKey("device_types.id"))
    name: Mapped[str] = mapped_column(String(80), index=True)
    transport: Mapped[str] = mapped_column(String(40))
    template: Mapped[str] = mapped_column(String(255))
    description: Mapped[str] = mapped_column(Text, default="")
    schema: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)

    device_type: Mapped[DeviceType] = relationship(back_populates="commands")


class CookingProgram(TimestampMixin, Base):
    __tablename__ = "cooking_programs"

    id: Mapped[int] = mapped_column(primary_key=True)
    device_type_id: Mapped[str] = mapped_column(ForeignKey("device_types.id"))
    name: Mapped[str] = mapped_column(String(160), index=True)
    mode: Mapped[str] = mapped_column(String(80), index=True)
    volume_group: Mapped[str] = mapped_column(String(80), index=True)
    dish_category: Mapped[str] = mapped_column(String(120), index=True)
    duration_minutes: Mapped[int] = mapped_column(Integer)
    temperature_celsius: Mapped[int] = mapped_column(Integer)
    mode_code: Mapped[int] = mapped_column(Integer)

    device_type: Mapped[DeviceType] = relationship(back_populates="cooking_programs")


class UserCookingProgram(TimestampMixin, Base):
    __tablename__ = "user_cooking_programs"
    __table_args__ = (
        UniqueConstraint("user_id", "device_type_id", "name", name="uq_user_program_name"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), default=1)
    device_type_id: Mapped[str] = mapped_column(ForeignKey("device_types.id"))
    name: Mapped[str] = mapped_column(String(160), index=True)
    mode: Mapped[str] = mapped_column(String(80), index=True)
    volume_group: Mapped[str] = mapped_column(String(80), default="Пользовательская")
    dish_category: Mapped[str] = mapped_column(String(120), default="Мои программы")
    duration_minutes: Mapped[int] = mapped_column(Integer)
    temperature_celsius: Mapped[int] = mapped_column(Integer)
    mode_code: Mapped[int] = mapped_column(Integer)


class Device(TimestampMixin, Base):
    __tablename__ = "devices"
    __table_args__ = (UniqueConstraint("external_id", name="uq_device_external_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"))
    device_type_id: Mapped[str] = mapped_column(ForeignKey("device_types.id"))
    external_id: Mapped[str] = mapped_column(String(120), index=True)
    name: Mapped[str] = mapped_column(String(160))
    connection_mode: Mapped[str] = mapped_column(String(40), default="ble")
    last_state: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)

    room: Mapped[Room] = relationship(back_populates="devices")
    device_type: Mapped[DeviceType] = relationship(back_populates="devices")
    telemetry_events: Mapped[list["TelemetryEvent"]] = relationship(
        back_populates="device", cascade="all, delete-orphan"
    )


class TelemetryEvent(TimestampMixin, Base):
    __tablename__ = "telemetry_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    device_id: Mapped[int] = mapped_column(ForeignKey("devices.id"))
    payload: Mapped[dict[str, Any]] = mapped_column(JSON)

    device: Mapped[Device] = relationship(back_populates="telemetry_events")
