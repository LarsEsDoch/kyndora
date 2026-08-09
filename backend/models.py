from typing import Optional, List
from uuid import UUID, uuid4
from sqlmodel import SQLModel, Field, Column
from sqlalchemy import JSON
from datetime import datetime, timedelta, timezone
import secrets


class User(SQLModel, table=True):
    __tablename__ = "users"
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    username: str = Field(index=True, unique=True)
    password_hash: str
    partner_id: Optional[UUID] = Field(default=None, foreign_key="users.id")

    latitude: Optional[float] = Field(default=None)
    longitude: Optional[float] = Field(default=None)
    location_updated_at: Optional[datetime] = Field(default=None)

    timezone_auto_detect: bool = Field(default=True)
    iana_timezone: Optional[str] = Field(default=None)

    mood: Optional[str] = Field(default=None)
    is_sleeping: bool = Field(default=False)
    status_updated_at: Optional[datetime] = Field(default=None)

    return_time: Optional[datetime] = Field(default=None)


class Device(SQLModel, table=True):
    __tablename__ = "devices"
    mac_address: str = Field(primary_key=True)
    name: str = Field(default=mac_address)
    user_id: UUID = Field(foreign_key="users.id")
    firmware_version: Optional[str] = None
    status: str = Field(default="offline")
    battery_level: Optional[int] = None
    last_seen_at: Optional[datetime] = None
    timezone: Optional[str] = Field(default="CET-1CEST,M3.5.0,M10.5.0/3")


class DeviceSettings(SQLModel, table=True):
    __tablename__ = "device_settings"
    mac_address: str = Field(foreign_key="devices.mac_address", primary_key=True)

    show_date_if_not_today: bool = Field(default=True)
    show_wifi: bool = Field(default=True)
    show_time: bool = Field(default=True)
    show_weather: bool = Field(default=True)
    show_sunrise_sunset: bool = Field(default=True)
    show_daily_message: bool = Field(default=True)
    show_tamagotchi: bool = Field(default=True)
    show_doodle: bool = Field(default=True)
    show_countdown: bool = Field(default=True)
    show_live_location: bool = Field(default=True)

    led_enabled: bool = Field(default=True)
    led_brightness: int = Field(default=80)
    adaptive_brightness: bool = Field(default=True)
    night_mode: bool = Field(default=False)
    night_brightness: int = Field(default=10)

    auto_update: bool = Field(default=True)
    update_hour: int = Field(default=3)
    update_minute: int = Field(default=0)

    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class MorningQuoteSettings(SQLModel, table=True):
    __tablename__ = "morning_quote_settings"
    user_id: UUID = Field(foreign_key="users.id", primary_key=True)
    wake_hour: int = Field(default=7)
    wake_minute: int = Field(default=0)
    quotes: List[str] = Field(default_factory=list, sa_column=Column(JSON))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ProvisioningTicket(SQLModel, table=True):
    __tablename__ = "provisioning_tickets"
    ticket_token: str = Field(default_factory=lambda: secrets.token_hex(16), primary_key=True)
    user_id: UUID = Field(foreign_key="users.id")
    expires_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc) + timedelta(minutes=15)
    )


class PartnerRequest(SQLModel, table=True):
    __tablename__ = "partner_requests"
    id: Optional[int] = Field(default=None, primary_key=True)
    sender_id: UUID = Field(foreign_key="users.id")
    receiver_id: UUID = Field(foreign_key="users.id")
    status: str = Field(default="pending")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ContentFeed(SQLModel, table=True):
    __tablename__ = "content_feed"
    id: Optional[int] = Field(default=None, primary_key=True)
    sender_id: UUID = Field(foreign_key="users.id")
    receiver_id: UUID = Field(foreign_key="users.id")
    content_type: str
    payload: str
    is_displayed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Telemetry(SQLModel, table=True):
    __tablename__ = "telemetry"
    id: Optional[int] = Field(default=None, primary_key=True)
    device_mac: str = Field(foreign_key="devices.mac_address", index=True)
    rssi: Optional[int] = None
    ssid: Optional[str] = None
    uptime_s: Optional[int] = None
    free_heap: Optional[int] = None
    core_temp: Optional[float] = None
    battery_v: Optional[float] = None
    battery_percent: Optional[int] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), index=True)