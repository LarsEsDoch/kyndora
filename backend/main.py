from fastapi import FastAPI
from contextlib import asynccontextmanager
from mqtt_client import connect_mqtt
from database import create_db_and_tables

from routers import auth, doodles, device

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting Backend.")
    create_db_and_tables()
    print("Starting MQTT Client.")
    connect_mqtt()
    yield

app = FastAPI(title="Kyndora API", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(doodles.router)
app.include_router(device.router)

@app.get("/")
def read_root():
    return {
        "status": "online",
        "system": "Kyndora Backend",
        "message": "All systems are running correctly. Go to /docs for the API overview."
    }