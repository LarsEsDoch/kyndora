from pydantic import BaseModel
from uuid import UUID

class UserCreate(BaseModel):
    username: str
    password: str

class ContentUpload(BaseModel):
    receiver_id: UUID
    content_type: str
    payload: str

class Token(BaseModel):
    access_token: str
    token_type: str

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float