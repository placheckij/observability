from pydantic_settings import BaseSettings, SettingsConfigDict

from utils import get_version_from_pyproject


class Settings(BaseSettings):
    """Application settings."""

    OBSERVABILITY_TEST_APP_VERSION: str = get_version_from_pyproject()

    # Pydantic basesettings configuration
    model_config = SettingsConfigDict(case_sensitive=True)


settings = Settings()
