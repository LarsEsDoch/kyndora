from typing import Optional
from uuid import UUID, uuid4
from sqlmodel import SQLModel, Field, Relationship

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