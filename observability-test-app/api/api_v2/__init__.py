from fastapi import APIRouter

api_router = APIRouter(prefix="/v2")


@api_router.get("/health", status_code=200, tags=["Health"])
async def api_health():
    return {"status": "ok"}


@api_router.get("/ping", status_code=200, tags=["Ping"])
async def api_ping():
    return
