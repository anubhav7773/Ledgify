from datetime import datetime, timezone
from fastapi import APIRouter
from app.core.config import settings
from app.core.database import check_database_health
from app.schemas.common import ApiResponse

router = APIRouter()


@router.get("", response_model=ApiResponse[dict])
async def health_check():
    """
    Comprehensive System Health Check:
    Verifies FastAPI server uptime, database connectivity, and API version.
    """
    db_healthy = await check_database_health()

    return ApiResponse(
        success=True,
        data={
            "service": settings.PROJECT_NAME,
            "status": "healthy" if db_healthy else "degraded",
            "environment": settings.ENVIRONMENT,
            "version": "1.0.0",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "database_connected": db_healthy,
        },
    )
