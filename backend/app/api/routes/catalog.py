from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.models import CookingProgram, DeviceType, UserCookingProgram
from app.schemas import (
    DeviceTypeRead,
    ProgramCategoryGroup,
    ProgramModeGroup,
    ProgramVolumeGroup,
    UserCookingProgramCreate,
    UserCookingProgramRead,
)

router = APIRouter(prefix="/device-types", tags=["device catalog"])


@router.get("", response_model=list[DeviceTypeRead])
def list_device_types(db: Session = Depends(get_db)) -> list[DeviceType]:
    stmt = (
        select(DeviceType)
        .where(DeviceType.is_active.is_(True))
        .options(selectinload(DeviceType.commands))
        .order_by(DeviceType.display_name)
    )
    return list(db.scalars(stmt))


@router.get("/{device_type_id}", response_model=DeviceTypeRead)
def get_device_type(device_type_id: str, db: Session = Depends(get_db)) -> DeviceType:
    device_type = db.scalar(
        select(DeviceType)
        .where(DeviceType.id == device_type_id)
        .options(selectinload(DeviceType.commands))
    )
    if device_type is None:
        raise HTTPException(status_code=404, detail="Device type not found")
    return device_type


@router.get("/{device_type_id}/programs", response_model=list[ProgramModeGroup])
def list_programs(device_type_id: str, db: Session = Depends(get_db)) -> list[ProgramModeGroup]:
    programs = list(
        db.scalars(
            select(CookingProgram)
            .where(CookingProgram.device_type_id == device_type_id)
            .order_by(
                CookingProgram.mode,
                CookingProgram.volume_group,
                CookingProgram.dish_category,
                CookingProgram.name,
            )
        )
    )
    if not programs and db.get(DeviceType, device_type_id) is None:
        raise HTTPException(status_code=404, detail="Device type not found")

    grouped: dict[str, dict[str, dict[str, list[CookingProgram]]]] = defaultdict(
        lambda: defaultdict(lambda: defaultdict(list))
    )
    for program in programs:
        grouped[program.mode][program.volume_group][program.dish_category].append(program)

    return [
        ProgramModeGroup(
            mode=mode,
            volumes=[
                ProgramVolumeGroup(
                    volume_group=volume,
                    categories=[
                        ProgramCategoryGroup(category=category, programs=category_programs)
                        for category, category_programs in categories.items()
                    ],
                )
                for volume, categories in volumes.items()
            ],
        )
        for mode, volumes in grouped.items()
    ]


@router.get("/{device_type_id}/user-programs", response_model=list[UserCookingProgramRead])
def list_user_programs(device_type_id: str, db: Session = Depends(get_db)) -> list[UserCookingProgram]:
    if db.get(DeviceType, device_type_id) is None:
        raise HTTPException(status_code=404, detail="Device type not found")
    return list(
        db.scalars(
            select(UserCookingProgram)
            .where(
                UserCookingProgram.device_type_id == device_type_id,
                UserCookingProgram.user_id == 1,
            )
            .order_by(UserCookingProgram.updated_at.desc(), UserCookingProgram.name)
        )
    )


@router.post("/{device_type_id}/user-programs", response_model=UserCookingProgramRead, status_code=201)
def create_user_program(
    device_type_id: str,
    payload: UserCookingProgramCreate,
    db: Session = Depends(get_db),
) -> UserCookingProgram:
    if db.get(DeviceType, device_type_id) is None:
        raise HTTPException(status_code=404, detail="Device type not found")

    program = db.scalar(
        select(UserCookingProgram).where(
            UserCookingProgram.device_type_id == device_type_id,
            UserCookingProgram.user_id == 1,
            UserCookingProgram.name == payload.name,
        )
    )
    if program is None:
        program = UserCookingProgram(device_type_id=device_type_id, user_id=1, **payload.model_dump())
        db.add(program)
    else:
        for field, value in payload.model_dump().items():
            setattr(program, field, value)

    db.commit()
    db.refresh(program)
    return program


@router.delete("/user-programs/{program_id}", status_code=204)
def delete_user_program(program_id: int, db: Session = Depends(get_db)) -> None:
    program = db.scalar(
        select(UserCookingProgram).where(
            UserCookingProgram.id == program_id,
            UserCookingProgram.user_id == 1,
        )
    )
    if program is None:
        raise HTTPException(status_code=404, detail="User program not found")
    db.delete(program)
    db.commit()
