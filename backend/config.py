from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path
from typing import Optional

class Settings(BaseSettings):
    AMADEUS_CLIENT_ID: Optional[str] = None
    AMADEUS_CLIENT_SECRET: Optional[str] = None
    TRAVELPAYOUTS_TOKEN: Optional[str] = None
    TEQUILA_API_KEY: Optional[str] = None
    # RapidAPI fallback for Kiwi
    RAPIDAPI_KEY: Optional[str] = None
    RAPIDAPI_HOST: Optional[str] = None  # e.g., "kiwi-com-cheap-flights.p.rapidapi.com"
    DUFFEL_ACCESS_TOKEN: Optional[str] = None
    DUFFEL_API_VERSION: str = "beta"
    CURRENCY: str = "EUR"
    CACHE_DB: str = "cache.db"
    # If true, pricing clients will skip reading/writing cache to always fetch fresh results
    DISABLE_CACHE: bool = True

    # Look for .env both at project root and backend dir
    _root_env = str((Path(__file__).resolve().parent.parent / ".env").as_posix())
    _local_env = str((Path(__file__).resolve().parent / ".env").as_posix())
    model_config = SettingsConfigDict(env_file=[_root_env, _local_env], env_file_encoding='utf-8')

settings = Settings()
