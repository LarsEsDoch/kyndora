import asyncio

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, list[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(user_id, []).append(websocket)

    def disconnect(self, user_id: str, websocket: WebSocket):
        conns = self.active_connections.get(user_id)
        if not conns:
            return
        if websocket in conns:
            conns.remove(websocket)
        if not conns:
            self.active_connections.pop(user_id, None)

    async def _send(self, user_id: str, message: dict):
        conns = list(self.active_connections.get(user_id, []))
        for ws in conns:
            try:
                await ws.send_json(message)
            except Exception:
                self.disconnect(user_id, ws)


manager = ConnectionManager()


def notify_user(user_id: str, message: dict, loop: asyncio.AbstractEventLoop):
    if loop is None:
        return
    asyncio.run_coroutine_threadsafe(manager._send(str(user_id), message), loop)
