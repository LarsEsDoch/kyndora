from pydantic import BaseModel
from uuid import UUID
from typing import Optional, List
from datetime import datetime


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


class DeviceSettingsUpdate(BaseModel):
    show_date_if_not_today: Optional[bool] = None
    show_wifi: Optional[bool] = None
    show_time: Optional[bool] = None
    show_weather: Optional[bool] = None
    show_sunrise_sunset: Optional[bool] = None
    show_daily_message: Optional[bool] = None
    show_tamagotchi: Optional[bool] = None
    show_doodle: Optional[bool] = None
    show_countdown: Optional[bool] = None
    show_live_location: Optional[bool] = None

    led_enabled: Optional[bool] = None
    led_brightness: Optional[int] = None
    adaptive_brightness: Optional[bool] = None
    night_mode: Optional[bool] = None
    night_brightness: Optional[int] = None

    auto_update: Optional[bool] = None
    update_hour: Optional[int] = None
    update_minute: Optional[int] = None


class MoodUpdate(BaseModel):
    mood: str
    is_sleeping: bool = False


class ReturnTimeUpdate(BaseModel):
    timestamp: datetime


class MorningQuotesUpdate(BaseModel):
    wake_hour: int
    wake_minute: int
    quotes: List[str]


class TimezoneUpdate(BaseModel):
    auto_detect: bool
    iana_timezone: Optional[str] = None