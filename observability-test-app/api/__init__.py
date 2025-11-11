import logging

from fastapi import APIRouter, Request

from api.api_v1 import api_router as api_v1_router
from api.api_v2 import api_router as api_v2_router

LOG = logging.getLogger(__name__)

api_router = APIRouter(prefix="/api")

api_router.include_router(api_v1_router)
api_router.include_router(api_v2_router)


@api_router.get("/health", status_code=200, tags=["Health"])
async def api_health():
    return {"status": "ok"}


@api_router.get("/ping", status_code=200, tags=["Ping"])
async def api_ping():
    return


@api_router.post("/alerts", status_code=200, tags=["Alerts"])
async def receive_alerts(request: Request):
    """Webhook endpoint to receive alerts from Alertmanager"""
    try:
        payload = await request.json()
        LOG.warning(f"🚨 ALERT RECEIVED: {payload.get('status', 'unknown').upper()}")

        for alert in payload.get("alerts", []):
            labels = alert.get("labels", {})
            annotations = alert.get("annotations", {})
            status = alert.get("status", "unknown")

            LOG.warning(
                f"  [{status.upper()}] {labels.get('alertname', 'Unknown')} - "
                f"{annotations.get('summary', 'No summary')} "
                f"(instance: {labels.get('instance', 'N/A')})"
            )

        return {"status": "received", "count": len(payload.get("alerts", []))}
    except Exception as e:
        LOG.error(f"Error processing alert: {e}")
        return {"status": "error", "message": str(e)}


@api_router.post("/alerts/critical", status_code=200, tags=["Alerts"])
async def receive_critical_alerts(request: Request):
    """Webhook endpoint for critical alerts"""
    try:
        payload = await request.json()
        LOG.critical(
            f"🔥 CRITICAL ALERT RECEIVED: {payload.get('status', 'unknown').upper()}"
        )

        for alert in payload.get("alerts", []):
            labels = alert.get("labels", {})
            annotations = alert.get("annotations", {})

            LOG.critical(
                f"  🔥 {labels.get('alertname', 'Unknown')} - "
                f"{annotations.get('summary', 'No summary')} "
                f"| {annotations.get('description', 'No description')}"
            )

        return {
            "status": "received",
            "severity": "critical",
            "count": len(payload.get("alerts", [])),
        }
    except Exception as e:
        LOG.error(f"Error processing critical alert: {e}")
        return {"status": "error", "message": str(e)}
