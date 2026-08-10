from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


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
    show_date_if_not_today: bool | None = None
    show_wifi: bool | None = None
    show_time: bool | None = None
    show_weather: bool | None = None
    show_sunrise_sunset: bool | None = None
    show_daily_message: bool | None = None
    show_tamagotchi: bool | None = None
    show_doodle: bool | None = None
    show_countdown: bool | None = None
    show_live_location: bool | None = None

    led_enabled: bool | None = None
    led_brightness: int | None = None
    adaptive_brightness: bool | None = None
    night_mode: bool | None = None
    night_brightness: int | None = None

    auto_update: bool | None = None
    update_hour: int | None = None
    update_minute: int | None = None


class MoodUpdate(BaseModel):
    mood: str
    is_sleeping: bool = False


class ReturnTimeUpdate(BaseModel):
    timestamp: datetime


class MorningQuotesUpdate(BaseModel):
    wake_hour: int
    wake_minute: int
    quotes: list[str]


class TimezoneUpdate(BaseModel):
    auto_detect: bool
    iana_timezone: str | None = None
