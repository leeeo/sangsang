# 상부상조 프로젝트 현황

> 한국형 경조사비 관리 플랫폼  
> 최종 업데이트: 2026-05-13

---

## 목차

1. [프로젝트 구조](#1-프로젝트-구조)
2. [기술 스택](#2-기술-스택)
3. [백엔드](#3-백엔드)
4. [관리자 웹](#4-관리자-웹)
5. [모바일 앱 (Flutter)](#5-모바일-앱-flutter)
6. [인증 방식](#6-인증-방식)
7. [환경 변수 설정](#7-환경-변수-설정)
8. [로컬 실행 방법](#8-로컬-실행-방법)
9. [남은 작업](#9-남은-작업)

---

## 1. 프로젝트 구조

```
sangbu-sangjo/
├── backend/                  # FastAPI 백엔드
│   ├── app/
│   │   ├── api/v1/
│   │   │   ├── endpoints/    # auth, users, transactions, categories,
│   │   │   │                 # analytics, relationships, admin
│   │   │   └── deps.py       # 인증 의존성
│   │   ├── core/             # config, database, security
│   │   ├── models/           # SQLAlchemy 모델
│   │   ├── schemas/          # Pydantic 스키마
│   │   └── main.py
│   ├── alembic/              # DB 마이그레이션
│   ├── tests/                # pytest 테스트 (32개)
│   └── pyproject.toml
├── frontend/
│   ├── admin-dashboard/      # React 관리자 웹 (Vite + TypeScript)
│   └── mobile/               # Flutter 모바일 앱
├── infrastructure/           # (예정) Docker, k8s, Terraform
└── docs/
    └── PROJECT_STATUS.md     # 이 파일
```

---

## 2. 기술 스택

| 영역 | 기술 |
|------|------|
| 백엔드 | Python 3.11+, FastAPI, SQLAlchemy 2.0, Alembic, Pydantic v2 |
| DB | SQLite (로컬) / PostgreSQL (프로덕션 전환 가능) |
| 인증 | JWT (python-jose), bcrypt, Google OAuth 2.0 (google-auth) |
| 관리자 웹 | React 18, TypeScript, Vite, Recharts, React Router v6 |
| 모바일 | Flutter 3, Provider, Dio, google_sign_in, shared_preferences |
| 테스트 | pytest, FastAPI TestClient (인메모리 SQLite) |

---

## 3. 백엔드

### 구현 완료된 API

| 접두사 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `/api/v1/auth` | `POST /register` | 이메일/비밀번호 회원가입 |
| | `POST /login` | 이메일/비밀번호 로그인 → JWT |
| | `POST /google` | Google ID 토큰 검증 → JWT |
| `/api/v1/users` | `GET /me` | 내 정보 조회 |
| | `PATCH /me` | 내 정보 수정 |
| `/api/v1/transactions` | `GET /` | 거래 목록 (필터, 페이지네이션) |
| | `POST /` | 거래 생성 → Relationship 집계 자동 갱신 |
| | `GET /{id}` | 거래 상세 |
| | `PATCH /{id}` | 거래 수정 (type 필드 포함) |
| | `DELETE /{id}` | 거래 삭제 → Relationship 집계 자동 차감 |
| `/api/v1/categories` | `GET /` | 카테고리 목록 |
| | `POST /` | 사용자 카테고리 생성 |
| | `PATCH /{id}` | 카테고리 수정 |
| | `DELETE /{id}` | 카테고리 삭제 |
| `/api/v1/analytics` | `GET /summary` | 월별 수입/지출 요약 |
| | `GET /trends` | 최근 N개월 트렌드 |
| | `GET /by-category` | 카테고리별 분석 |
| | `GET /counterparty` | 상대방별 통계 |
| `/api/v1/relationships` | `GET /` | 관계 목록 |
| | `POST /` | 관계 등록 (counterparty_name 1~100자) |
| | `GET /{id}` | 관계 상세 |
| | `PATCH /{id}` | 관계 메모/유형 수정 |
| `/api/v1/admin` | `GET /stats` | 서비스 전체 통계 (superuser) |
| | `GET /users` | 전체 사용자 목록/검색 |
| | `GET /users/{id}` | 사용자 상세 + 최근 거래 |
| | `PATCH /users/{id}` | 활성/비활성, superuser 변경 |
| | `DELETE /users/{id}` | 사용자 소프트 삭제 |
| | `GET /transactions` | 전체 거래 조회 |
| | `GET /categories` | 시스템 카테고리 목록 |
| | `POST /categories` | 시스템 카테고리 생성 |
| | `PATCH /categories/{id}` | 시스템 카테고리 수정 |
| | `DELETE /categories/{id}` | 시스템 카테고리 삭제 |
| | `GET /analytics/trends` | 서비스 전체 월별 트렌드 |
| | `GET /analytics/by-category` | 서비스 전체 카테고리 분석 |

### DB 모델

| 모델 | 주요 필드 |
|------|----------|
| `User` | email, username, full_name, hashed_password (nullable), google_id, is_active, is_superuser |
| `Transaction` | user_id, category_id, amount, type (income/expense), transaction_date, counterparty_name, memo, event_type |
| `Category` | user_id (null=시스템), name, type, icon, color, is_system, parent_id |
| `Relationship` | user_id, counterparty_name, relationship_type, total_given, total_received, last_transaction_date |

### 핵심 비즈니스 로직

- **Relationship 집계 자동 갱신**: 거래 생성/삭제 시 `total_given` / `total_received` 실시간 업데이트
  - `expense` 거래 → `total_given` 증가 (내가 더 준 금액)
  - `income` 거래 → `total_received` 증가 (내가 받은 금액)
  - `balance = total_given - total_received` (양수: 내가 더 줌)

### 테스트 현황

```
tests/
├── conftest.py          # 인메모리 SQLite, TestClient, 공통 픽스처
├── test_auth.py         # 회원가입/로그인
├── test_transactions.py # 거래 CRUD, 필터
├── test_analytics.py    # 분석 API
├── test_admin.py        # 관리자 API 8개 (superuser 권한 검증 포함)
└── test_relationships.py # 관계 CRUD + 거래 연동 집계 8개

총 32개 테스트, 전체 통과
```

---

## 4. 관리자 웹

**경로**: `frontend/admin-dashboard/`  
**접근**: superuser 계정 전용, 이메일/비밀번호 로그인만 지원

### 구현된 페이지

| 경로 | 페이지 | 기능 |
|------|--------|------|
| `/` | Dashboard | 전체 사용자·거래 통계, 월별 신규 가입 차트 |
| `/users` | 사용자 관리 | 목록/검색, 활성화·비활성화, 삭제 |
| `/transactions` | 거래 내역 | 전체 거래 조회, 유형 필터, 페이지네이션 |
| `/analytics` | 분석 | 서비스 전체 월별 트렌드 바차트, 카테고리별 비율 |
| `/categories` | 카테고리 관리 | 시스템 카테고리 CRUD |
| `/login` | 로그인 | 관리자 전용 (일반 회원가입 없음) |

---

## 5. 모바일 앱 (Flutter)

**경로**: `frontend/mobile/`

### 구현된 화면

| 경로 | 화면 | 기능 |
|------|------|------|
| (진입점) | 스플래시/라우팅 | 토큰 확인 후 홈/로그인 분기 |
| `/login` | 로그인 | 이메일/비밀번호, **Google 로그인 버튼** |
| `/login` → 회원가입 | 회원가입 | 이메일·아이디·이름·비밀번호, 확인 |
| `/home` | 홈 | 이번 달 수입/지출 요약, 최근 거래 5건, 빠른 메뉴 (관계/분석) |
| `/transactions` | 거래 목록 | 전체 거래, 유형 필터 |
| `/transactions/new` | 거래 등록 | 카테고리·금액·날짜·상대방·메모 입력 |
| `/relationships` | 관계 관리 | 관계 목록 (잔액 표시), 관계 등록 |
| `/analytics` | 분석 | 탭 2개: 월별 요약 + 카테고리 바, 트렌드 목록 |

### 주요 Provider

| Provider | 역할 |
|----------|------|
| `AuthProvider` | 로그인, 구글 로그인, 회원가입, 로그아웃, 내 정보 |
| `TransactionProvider` | 거래 목록 조회, 생성, 삭제 |
| `CategoryProvider` | 카테고리 목록 |
| `AnalyticsProvider` | 월별 요약, 트렌드, 카테고리별 분석 |
| `RelationshipProvider` | 관계 목록, 생성, 수정 |

### API 클라이언트 (플랫폼 분기)

```dart
// Android 에뮬레이터 → 10.0.2.2 (호스트 localhost alias)
// iOS 시뮬레이터 / 실기기 → localhost
// 빌드 시 --dart-define=API_URL=https://... 로 덮어쓰기 가능
```

---

## 6. 인증 방식

### 이메일/비밀번호

```
[앱/관리자웹] → POST /api/v1/auth/login (form: username, password)
             ← { access_token: "..." }
```

- 관리자 웹: superuser 계정만 허용
- 모바일 앱: 일반 사용자

### Google OAuth 2.0

```
[Flutter] → google_sign_in.signIn() → idToken 획득
[Flutter] → POST /api/v1/auth/google { id_token }
[백엔드]  → google-auth 라이브러리로 서명 검증
          → 신규: User 자동 생성 (username = email 앞부분 + 랜덤)
          → 기존 이메일 계정: google_id 연동
[백엔드]  ← { access_token: "..." }
```

**활성화 조건**: `.env`에 `GOOGLE_CLIENT_ID` 설정 필요. 미설정 시 503 응답.

---

## 7. 환경 변수 설정

### 백엔드 `.env`

```env
# 필수
SECRET_KEY=<python -c "import secrets; print(secrets.token_urlsafe(32))">

# DB (기본값: SQLite)
DATABASE_URL=sqlite:///./sangbusangjo.db
# PostgreSQL 예시:
# DATABASE_URL=postgresql+psycopg2://user:password@localhost:5432/sangbusangjo

# Google OAuth (없으면 구글 로그인 비활성화)
GOOGLE_CLIENT_ID=<Google Cloud Console에서 발급>
```

### Flutter 빌드 시

```bash
# 개발
flutter run \
  --dart-define=API_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=GOOGLE_CLIENT_ID=<your-client-id>

# 프로덕션
flutter build apk \
  --dart-define=API_URL=https://api.your-domain.com/api/v1 \
  --dart-define=GOOGLE_CLIENT_ID=<your-client-id>
```

### Google OAuth 설정 체크리스트

- [ ] [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → OAuth 2.0 클라이언트 ID 생성
- [ ] Android 패키지명(`com.example.sangbu_sangjo`) 등록
- [ ] iOS 번들 ID 등록
- [ ] `android/app/google-services.json` 추가
- [ ] `ios/Runner/GoogleService-Info.plist` 추가
- [ ] 백엔드 `.env`에 `GOOGLE_CLIENT_ID` 설정

---

## 8. 로컬 실행 방법

### 백엔드

```bash
cd sangbu-sangjo/backend

# 1. 의존성 설치
poetry install

# 2. 환경 변수 설정
cp .env.example .env
# .env에서 SECRET_KEY 설정

# 3. DB 마이그레이션
poetry run alembic upgrade head

# 4. 서버 실행 (기본 포트 8000)
poetry run uvicorn app.main:app --reload

# 5. 테스트
poetry run pytest
```

### 관리자 웹

```bash
cd sangbu-sangjo/frontend/admin-dashboard

npm install
npm run dev   # http://localhost:5174

# 빌드
npm run build
```

### Flutter 모바일

```bash
cd sangbu-sangjo/frontend/mobile

flutter pub get
flutter run   # 에뮬레이터/시뮬레이터 실행
```

> **첫 관리자 계정 생성**: API 서버 실행 후 `/api/v1/auth/register`로 계정 생성 →  
> DB에서 `UPDATE users SET is_superuser = 1 WHERE email = '...'` 실행

---

## 9. 남은 작업

### 우선순위 높음

| 항목 | 내용 |
|------|------|
| **인프라 구성** | `infrastructure/` 비어있음 — Dockerfile, docker-compose 작성 필요 |
| **관리자 웹 거래 삭제** | 현재 조회만 가능, 특정 거래 삭제 기능 없음 |

### 우선순위 중간

| 항목 | 내용 |
|------|------|
| **GitHub Actions CI/CD** | 자동 테스트 + 빌드 파이프라인 없음 |
| **프론트엔드 테스트** | React/Flutter 테스트 전무 |
| **관리자 계정 생성 자동화** | 현재 DB 직접 수정 필요, 초기화 스크립트 없음 |

### 우선순위 낮음

| 항목 | 내용 |
|------|------|
| **WebSocket 실시간 알림** | 설계에 있으나 미구현 |
| **Redis 캐싱** | 설정만 있고 실제 미연동 |
| **PWA** | Service Worker 없음 |
| **번들 최적화** | 관리자 웹 청크 679KB (recharts 포함) — code splitting 고려 |
