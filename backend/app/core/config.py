from typing import List, Union
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Ledgify Fintech Backend"
    API_V1_STR: str = "/api/v1"
    PORT: int = 8000
    HOST: str = "0.0.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # Supabase Configuration
    SUPABASE_URL: str = "https://bbkftnptmxjpbusjpqbg.supabase.co"
    SUPABASE_SERVICE_ROLE_KEY: str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJia2Z0bnB0bXhqcGJ1c2pwcWJnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODE1ODA1MywiZXhwIjoyMTAzNzM0MDUzfQ.j3mvuLysyc0-q6XYGAghK7lvGkEsyi07rOZpUaIbSGg"
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_JWT_SECRET: str = "super-secret-jwt-key-placeholder"

    # AI & Multimodal Credentials
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL_NAME: str = "gemini-3.1-flash-lite"

    # Google Play Billing
    GOOGLE_PLAY_PACKAGE_NAME: str = "com.asiverticals.ledgify"
    GOOGLE_APPLICATION_CREDENTIALS_JSON: str = ""

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="allow",
    )


settings = Settings()
