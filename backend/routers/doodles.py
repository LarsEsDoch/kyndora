from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from database import get_session
from models import ContentFeed
from mqtt_client import publish_message
from schemas import ContentUpload
from security import get_current_user_id

router = APIRouter(prefix="/content", tags=["Messages & Doodles"])


@router.post("/send", status_code=201)
def send_content(
    data: ContentUpload,
    session: Session = Depends(get_session),
    current_user_id: str = Depends(get_current_user_id),
):

    new_content = ContentFeed(
        sender_id=current_user_id,
        receiver_id=data.receiver_id,
        content_type=data.content_type,
        payload=data.payload,
    )
    session.add(new_content)
    session.commit()
    session.refresh(new_content)

    topic = f"kyndora/{data.receiver_id}/notify"
    publish_message(topic, "NEW_CONTENT")

    return {"status": "success", "content_id": new_content.id}


@router.get("/latest")
def get_latest_content(
    session: Session = Depends(get_session),
    current_user_id: str = Depends(get_current_user_id),
):

    statement = (
        select(ContentFeed)
        .where(
            ContentFeed.receiver_id == current_user_id,
            ContentFeed.is_displayed == False,
        )
        .order_by(ContentFeed.created_at.asc())
    )

    content = session.exec(statement).first()

    if not content:
        raise HTTPException(status_code=404, detail="No new messages!")

    content.is_displayed = True
    session.add(content)
    session.commit()

    return {
        "type": content.content_type,
        "payload": content.payload,
        "sent_at": content.created_at,
    }
