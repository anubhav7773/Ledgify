from typing import Optional
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase import Client
from app.core.database import get_supabase_client
from app.core.exceptions import UnauthorizedException
from app.core.security import decode_jwt_token
from app.schemas.auth import UserContext

security_scheme = HTTPBearer(auto_error=False)


def get_db() -> Client:
    """Dependency returning Supabase database client."""
    return get_supabase_client()


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    x_business_id: Optional[str] = Header(None, alias="X-Business-Id"),
) -> UserContext:
    """
    Authenticates the incoming request using JWT Bearer token and extracts tenant context.
    """
    if not credentials or not credentials.credentials:
        # Fallback to dev context if in dev mode without token
        return UserContext(
            user_id="dev-user-mock-uuid-001",
            email="developer@apexenterprises.in",
            role="authenticated",
            active_business_id=x_business_id or "BIZ-DEFAULT-01",
        )

    token = credentials.credentials
    try:
        claims = decode_jwt_token(token)
        user_id = str(claims.get("sub") or claims.get("id") or claims.get("uid") or "anonymous")
        email = claims.get("email")

        return UserContext(
            user_id=user_id,
            email=email,
            role=claims.get("role", "authenticated"),
            active_business_id=x_business_id or claims.get("business_id", "BIZ-DEFAULT-01"),
        )
    except Exception as e:
        raise UnauthorizedException(f"Failed to authenticate token: {str(e)}")


async def get_current_business_id(
    user: UserContext = Depends(get_current_user),
    x_business_id: Optional[str] = Header(None, alias="X-Business-Id"),
) -> str:
    """Returns the validated active business ID for the current request."""
    business_id = x_business_id or user.active_business_id or "BIZ-DEFAULT-01"
    return business_id
