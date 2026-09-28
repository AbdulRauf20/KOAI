from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    groq_api_key: str
    groq_model: str = "openai/gpt-oss-20b"
    ai_timeout_seconds: float = 10.0

    model_config = SettingsConfigDict(env_file=".env")


settings = Settings()