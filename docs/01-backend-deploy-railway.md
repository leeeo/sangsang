# 01. 백엔드 배포 — Railway

상부상조 백엔드(FastAPI + PostgreSQL)를 **Railway**에 배포하는 절차입니다. [PLAN.md](../PLAN.md)의 **Phase 3**에 해당하며, 앱/웹이 바라볼 실제 API 주소가 여기서 나오므로 스토어 출시보다 먼저 완료해야 합니다.

## 사전 준비
- GitHub `leeeo/sangsang` 저장소 push 완료 ✅
- Railway 계정 ([railway.app](https://railway.app) → GitHub 로그인)

---

## 1. 프로젝트 생성 + 저장소 연결
1. Railway 대시보드 → **New Project** → **Deploy from GitHub repo** → `leeeo/sangsang` 선택
2. 서비스 생성 후 **Settings → Root Directory = `backend`** 로 설정 (모노레포이므로 필수)
   - Railway가 `backend/Dockerfile` 과 `backend/railway.json`(빌더·헬스체크 설정)을 자동 인식합니다.

## 2. PostgreSQL 추가
1. 프로젝트에서 **New → Database → Add PostgreSQL**
2. 생성된 Postgres 서비스 자격증명은 3번에서 변수 참조로 주입합니다.
   - ⚠️ 앱은 SQLAlchemy `postgresql+psycopg2://...` 드라이버 접두사가 필요합니다(아래에서 처리).

## 3. 환경 변수 설정 (backend 서비스 → Variables)

| 변수 | 값 |
|---|---|
| `DATABASE_URL` | `postgresql+psycopg2://${{Postgres.PGUSER}}:${{Postgres.PGPASSWORD}}@${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/${{Postgres.PGDATABASE}}` |
| `SECRET_KEY` | **새로 생성** (dev와 다른 값): `python -c "import secrets; print(secrets.token_urlsafe(32))"` |
| `GOOGLE_CLIENT_ID` | Phase 4에서 발급. 지금은 비워도 됨(구글 로그인만 비활성, 503) |
| `CORS_ORIGINS` | 관리자 웹 배포 후 실제 도메인. 예: `["https://admin.example.com"]` |

> `${{Postgres.*}}` 는 Railway가 Postgres 서비스 자격증명을 자동 주입하는 참조 문법입니다. `postgresql+psycopg2://` 접두사만 직접 붙이면 됩니다.
> `SECRET_KEY` 는 **절대 커밋 금지** — Railway 환경변수로만 관리합니다.

## 4. 배포 확인
- Railway가 자동 빌드/배포합니다. **Deploy Logs** 에서 확인:
  - `alembic upgrade head` (마이그레이션) 성공
  - `Uvicorn running on http://0.0.0.0:<PORT>` (포트는 `$PORT` 자동 바인딩)
- **Settings → Networking → Generate Domain** → 공개 도메인 발급 (예: `https://sangsang-backend-xxxx.up.railway.app`)
- 헬스체크: `https://<도메인>/health` → `{"status":"ok"}`
- API 스키마: `https://<도메인>/api/v1/openapi.json`

## 5. 관리자(superuser) 계정 생성
프로덕션 DB를 대상으로 한 번만 실행:
```bash
poetry run python scripts/create_superuser.py \
  --email <admin@you> --username admin --password "<강한비밀번호>" --full-name 관리자
```
> Railway는 임시 셸이 제한적이므로, 로컬에서 `DATABASE_URL`을 프로덕션 값으로 지정해 실행하거나 Railway CLI(`railway run`)를 사용하세요.

## 6. 이 도메인의 용도 (다음 Phase)
- **Phase 4** 프로덕션 Google OAuth 리다이렉트/동의 화면
- **Phase 6** 앱 빌드 시 주입: `flutter build appbundle --release --dart-define=API_URL=https://<도메인>/api/v1`

---

## 참고 / 주의
- 개발용 [`docker-compose.yml`](../docker-compose.yml)의 소스 볼륨 마운트와 `--reload`는 프로덕션과 무관합니다. Railway는 `backend/Dockerfile`의 `CMD`(`$PORT` 자동 바인딩)를 사용합니다.
- 무료 크레딧 소진 후 과금될 수 있으니 Railway 사용량을 확인하세요.
- DB 백업: Railway Postgres의 백업/스냅샷 설정을 켜 두세요(사용자 재무 데이터).
