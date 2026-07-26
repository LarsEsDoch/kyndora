from fastapi import FastAPI
from contextlib import asynccontextmanager
from mqtt_client import connect_mqtt

from routers import auth, doodles

@asynccontextmanager
async def lifespan(app: FastAPI):
    connect_mqtt()
    yield

app = FastAPI(title="Kyndora API", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(doodles.router)

@app.get("/")
def read_root():
    return {
        "status": "online",
        "system": "Kyndora Backend",
        "message": "All systems are running correctly. Go to /docs for the API overview."
    }