from fastapi import APIRouter, Depends
from sqlmodel import Session
from datetime import datetime, timezone

from database import get_session
from models import User
from schemas import LocationUpdate
from security import get_current_user

router = APIRouter(prefix="/api/users", tags=["users"])


@router.post("/location")
def update_location(
    data: LocationUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    current_user.latitude = data.latitude
    current_user.longitude = data.longitude
    current_user.location_updated_at = datetime.now(timezone.utc)

    session.add(current_user)
    session.commit()

    return {"status": "success", "message": "Location updated."}