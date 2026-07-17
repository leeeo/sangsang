from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)

    # 프로젝트
    PROJECT_NAME: str = "상부상조"
    API_V1_STR: str = "/api/v1"

    # 데이터베이스 - SQLite(로컬) / PostgreSQL(CI, 프로덕션) 전환 가능
    # SQLite 예시:  sqlite:///./sangbusangjo.db
    # PostgreSQL:   postgresql+psycopg2://user:pass@host:5432/dbname
    DATABASE_URL: str = "sqlite:///./sangbusangjo.db"

    # JWT - 반드시 .env에서 안전한 값으로 설정할 것
    # 생성: python -c "import secrets; print(secrets.token_urlsafe(32))"
    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    def model_post_init(self, __context: object) -> None:
        if not self.SECRET_KEY:
            raise ValueError(
                "SECRET_KEY가 설정되지 않았습니다. "
                ".env 파일에 SECRET_KEY=<안전한 랜덤 값> 을 설정하세요.\n"
                "생성 명령: python -c \"import secrets; print(secrets.token_urlsafe(32))\""
            )

    # Google OAuth
    # Google Cloud Console > APIs & Services > Credentials 에서 발급
    # https://console.cloud.google.com/apis/credentials
    GOOGLE_CLIENT_ID: str = ""  # .env에서 설정: GOOGLE_CLIENT_ID=<your-client-id>

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # CORS
    CORS_ORIGINS: list[str] = [
        "http://localhost:5173",  # 사용자 웹 (Vite)
        "http://localhost:5174",  # 관리자 대시보드 (Vite)
        "http://localhost:3000",
        "http://localhost:8080",
    ]


settings = Settings()
