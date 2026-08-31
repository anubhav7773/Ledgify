import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.api import api_router
from app.core.config import settings
from app.core.database import get_supabase_client
from app.core.exceptions import (
    LedgifyException,
    generic_http_exception_handler,
    ledgify_exception_handler,
)

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("ledgify-backend")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle event handler for FastAPI startup and shutdown."""
    logger.info(f"Starting {settings.PROJECT_NAME} in [{settings.ENVIRONMENT}] environment...")
    # Initialize Supabase Client pool
    get_supabase_client()
    logger.info("Database connection verified.")
    yield
    logger.info("Shutting down Ledgify FastAPI application...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

# Configure CORS Middleware
if settings.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Register Custom Exception Handlers
app.add_exception_handler(LedgifyException, ledgify_exception_handler)
app.add_exception_handler(HTTPException, generic_http_exception_handler)

# Include Main API Router
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/")
async def root_redirect():
    """Root redirect endpoint with basic metadata."""
    return {
        "project": settings.PROJECT_NAME,
        "docs_url": f"{settings.API_V1_STR}/docs",
        "health_url": f"{settings.API_V1_STR}/health",
        "status": "online",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
