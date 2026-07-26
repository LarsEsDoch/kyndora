import os
from sqlmodel import create_engine, Session
from dotenv import load_dotenv

load_dotenv()

DB_URL = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@192.168.178.33:5432/connect_box"

engine = create_engine(DB_URL, echo=True)

def get_session():
    with Session(engine) as session:
        yield session