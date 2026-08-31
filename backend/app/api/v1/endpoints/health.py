from datetime import datetime, timezone
from fastapi import APIRouter, Response, status
from app.core.config import settings
from app.core.database import check_database_health
from app.schemas.common import ApiResponse

router = APIRouter()


@router.api_route("", methods=["GET", "HEAD"], response_model=ApiResponse[dict])
async def health_check(response: Response):
    """
    Comprehensive System Health Check & UptimeRobot Probe:
    Supports both GET and HEAD HTTP methods with fast 200 OK return.
    """
    db_healthy = await check_database_health()
    response.headers["X-Service"] = settings.PROJECT_NAME
    response.headers["X-Status"] = "UP"

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


@router.api_route("/ping", methods=["GET", "HEAD"], status_code=status.HTTP_200_OK)
async def uptime_robot_ping(response: Response):
    """
    Ultra-lightweight ping probe for UptimeRobot (HEAD / GET).
    Returns 200 OK with zero payload overhead to prevent Render instance sleep.
    """
    response.headers["X-Uptime-Status"] = "PONG"
    return Response(content="OK", media_type="text/plain", status_code=status.HTTP_200_OK)
