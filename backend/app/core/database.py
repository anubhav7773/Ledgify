import logging
from typing import Optional
from supabase import create_client, Client
from app.core.config import settings

logger = logging.getLogger(__name__)

_supabase_client: Optional[Client] = None


def get_supabase_client() -> Client:
    """Returns the singleton Supabase client initialized with service role privileges."""
    global _supabase_client
    if _supabase_client is None:
        try:
            _supabase_client = create_client(
                supabase_url=settings.SUPABASE_URL,
                supabase_key=settings.SUPABASE_SERVICE_ROLE_KEY,
            )
            logger.info("Supabase service client initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize Supabase client: {e}")
            raise e
    return _supabase_client


async def check_database_health() -> bool:
    """Pings Supabase by performing a lightweight query."""
    try:
        client = get_supabase_client()
        # Ping table with limit 1
        res = client.table("tenants").select("id").limit(1).execute()
        return res is not None
    except Exception as e:
        logger.warning(f"Database health check failed: {e}")
        # Even if table is empty or connection fails in test mode, return status
        return False
