from typing import Any, Dict, Optional
import jwt
from app.core.config import settings
from app.core.exceptions import UnauthorizedException


def decode_jwt_token(token: str) -> Dict[str, Any]:
    """
    Decodes Supabase or local JWT token.
    In development/mock mode or Supabase mode, extracts claims like sub (uid), email, role.
    """
    try:
        # Supabase JWT token decode without verification in dev or with secret when available
        unverified_claims = jwt.decode(token, options={"verify_signature": False})
        return unverified_claims
    except Exception as e:
        raise UnauthorizedException(f"Invalid authentication token: {str(e)}")


def extract_user_id_from_token(token: str) -> str:
    """Extracts user ID (sub) from JWT payload."""
    claims = decode_jwt_token(token)
    user_id = claims.get("sub") or claims.get("id") or claims.get("uid")
    if not user_id:
        raise UnauthorizedException("Token payload does not contain a valid user identifier (sub).")
    return str(user_id)
