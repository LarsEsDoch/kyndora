from contextlib import asynccontextmanager

from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware

from database import create_db_and_tables
from mqtt_client import connect_mqtt
from routers import auth, device, doodles, feed, mqtt, partners, users
from services.mqtt_worker import init_mqtt_worker
from services.weather_worker import init_weather_worker


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting Backend.")
    create_db_and_tables()
    print("Starting MQTT Client.")
    connect_mqtt()
    print("Starting MQTT Worker.")
    init_mqtt_worker()
    print("Starting Weather Worker.")
    init_weather_worker()
    yield


app = FastAPI(title="Kyndora API", lifespan=lifespan)

origins = [
    "http://localhost",
    "http://localhost:8080",
    "http://localhost:51117",
    "https://api.bogatzhome.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(doodles.router)
app.include_router(device.router)
app.include_router(mqtt.router)
app.include_router(partners.router)
app.include_router(feed.router)
app.include_router(users.router)


@app.get("/")
def read_root():
    return {
        "status": "online",
        "system": "Kyndora Backend",
        "message": "All systems are running correctly. Go to /docs for the API overview.",
    }
