from fastapi import FastAPI, Depends, HTTPException, status
from sqlmodel import Session, select
from pydantic import BaseModel

from database import get_session
from models import User
from fastapi.security import OAuth2PasswordRequestForm
from security import get_password_hash, verify_password, create_access_token, get_current_user_id

app = FastAPI(title="Kyndora API")


class UserCreate(BaseModel):
    username: str
    password: str


@app.get("/")
def read_root():
    return {"status": "online", "system": "Kyndora Backend ist bereit."}


@app.post("/register", status_code=status.HTTP_201_CREATED)
def register_user(user_data: UserCreate, session: Session = Depends(get_session)):
    statement = select(User).where(User.username == user_data.username)
    existing_user = session.exec(statement).first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This user is already registered."
        )

    hashed_pwd = get_password_hash(user_data.password)

    new_user = User(
        username=user_data.username,
        password_hash=hashed_pwd
    )

    session.add(new_user)
    session.commit()
    session.refresh(new_user)

    return {"message": "Successfully registered user!", "user_id": new_user.id}


@app.post("/login")
def login(
        form_data: OAuth2PasswordRequestForm = Depends(),
        session: Session = Depends(get_session)
):
    statement = select(User).where(User.username == form_data.username)
    user = session.exec(statement).first()

    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Wrong username oder password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": str(user.id)})

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "message": f"Welcome back, {user.username}!"
    }

@app.get("/users/me")
def read_users_me(current_user_id: str = Depends(get_current_user_id)):
    return {
        "user_id": current_user_id,
        "message": "Only you can see this information, because only you have a valid token!."
    }