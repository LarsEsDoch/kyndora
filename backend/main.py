from fastapi import FastAPI, Depends, HTTPException, status
app = FastAPI(title="Connect-Box API")


class UserCreate(BaseModel):
    username: str
    password: str
