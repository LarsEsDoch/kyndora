from typing import Optional
from uuid import UUID, uuid4
from sqlmodel import SQLModel, Field
from datetime import datetime, timedelta, timezone
import secrets

class User(SQLModel, table=True):
    __tablename__ = "users"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    username: str = Field(index=True, unique=True)
    password_hash: str
    partner_id: Optional[UUID] = Field(default=None, foreign_key="users.id")


class Device(SQLModel, table=True):
    __tablename__ = "devices"

    mac_address: str = Field(primary_key=True)
    user_id: UUID = Field(foreign_key="users.id")
    firmware_version: Optional[str] = None


class ProvisioningTicket(SQLModel, table=True):
    __tablename__ = "provisioning_tickets"

    ticket_token: str = Field(default_factory=lambda: secrets.token_hex(16), primary_key=True)
    user_id: UUID = Field(foreign_key="users.id")
    expires_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc) + timedelta(minutes=15)
    )


class ContentFeed(SQLModel, table=True):
    __tablename__ = "content_feed"

    id: Optional[int] = Field(default=None, primary_key=True)
    sender_id: UUID = Field(foreign_key="users.id")
    receiver_id: UUID = Field(foreign_key="users.id")
    content_type: str
    payload: str
    is_displayed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))