from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from security import decode_token_to_user_id
from ws_manager import manager

router = APIRouter(tags=["realtime"])


@router.websocket("/ws/events")
async def websocket_events(websocket: WebSocket, token: str):
    try:
        user_id = decode_token_to_user_id(token)
    except ValueError:
        await websocket.close(code=4401)
        return

    await manager.connect(str(user_id), websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(str(user_id), websocket)
