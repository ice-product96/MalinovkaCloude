from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.models import Device, DeviceType, Room
from app.schemas import RoomCreate, RoomRead, RoomUpdate

router = APIRouter(prefix="/rooms", tags=["rooms"])


@router.get("", response_model=list[RoomRead])
def list_rooms(db: Session = Depends(get_db)) -> list[Room]:
    stmt = (
        select(Room)
        .options(selectinload(Room.devices).selectinload(Device.device_type).selectinload(DeviceType.commands))
        .order_by(Room.name)
    )
    return list(db.scalars(stmt))


@router.post("", response_model=RoomRead, status_code=201)
def create_room(payload: RoomCreate, db: Session = Depends(get_db)) -> Room:
    room = Room(name=payload.name)
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


@router.patch("/{room_id}", response_model=RoomRead)
def update_room(room_id: int, payload: RoomUpdate, db: Session = Depends(get_db)) -> Room:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    room.name = payload.name
    db.commit()
    db.refresh(room)
    return room


@router.delete("/{room_id}", status_code=204)
def delete_room(room_id: int, db: Session = Depends(get_db)) -> Response:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    has_devices = db.scalar(select(Device).where(Device.room_id == room_id).limit(1))
    if has_devices is not None:
        raise HTTPException(status_code=409, detail="Move devices before deleting room")
    db.delete(room)
    db.commit()
    return Response(status_code=204)
