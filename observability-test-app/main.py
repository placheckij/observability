import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI

from api import api_router
from core.config import settings

LOG = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Startup logic here (before yield)
    LOG.info("Application startup")
    LOG.info(
        f"Observability-test-app version: {settings.OBSERVABILITY_TEST_APP_VERSION}"
    )

    yield

    # Shutdown logic here (after yield)
    LOG.info("Application shutdown")


app = FastAPI(
    title="observability-test-app",
    openapi_url="/openapi.json",
    lifespan=lifespan,
    version=settings.OBSERVABILITY_TEST_APP_VERSION,
    separate_input_output_schemas=True,
)

app.include_router(api_router)


# Health check endpoint for Docker HEALTHCHECK (CIS 4.7)
@app.get("/health", tags=["health"])
async def health_check():
    """Health check endpoint for monitoring and Docker health checks."""
    return {"status": "healthy", "version": settings.OBSERVABILITY_TEST_APP_VERSION}
