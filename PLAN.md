# 상부상조 출시 실행 플랜

개발은 완료된 상태입니다. 이 문서는 **지금부터 서버 배포·스토어 출시·운영까지** 남은 일을 순서대로 추적하는 체크리스트입니다. 각 단계의 상세 절차는 (작성 예정인) `docs/`에 연결됩니다.

> 사용법: 한 단계씩 진행하며 `[ ]`를 `[x]`로 바꿔 기록하세요. 위에서 아래가 의존성 순서입니다.
>
> ⚠️ Color Rush(leeeo-fable)와 달리 **상부상조는 서버(백엔드 API)가 필요한 앱**입니다. 스토어 출시·앱 프로덕션 빌드보다 **백엔드 배포가 먼저** 와야 합니다. 또한 광고/인앱결제가 없어 해당 단계는 제외했습니다.

---

## 현재 상태 요약

| 영역 | 상태 |
|---|---|
| 백엔드 API (FastAPI, 32 tests) | ✅ 완료 |
| 관리자 웹 (React + Vite) | ✅ 완료 |
| 모바일 앱 (Flutter, `com.sangbusangjo.mobile` v1.0.0+1) | ✅ 완료 |
| CI 워크플로 (GitHub Actions) | ✅ 작성됨 (push 후 자동 활성화) |
| GitHub 업로드 | ✅ 완료 (github.com/leeeo/sangsang) |
| **백엔드 배포(호스팅)** | ⬜ 미완 ← 스토어보다 먼저 |
| 프로덕션 Google OAuth | ⬜ 미완 |
| 개인정보처리방침 + 웹사이트 | ⬜ 미완 (금융·개인정보 앱 필수) |
| 앱 서명 키 + 스토어 등록 | ⬜ 미완 |

---

## Phase 1 — 로컬 통합 검증 (약 30분)

- [ ] `docker compose up` 으로 db+backend+admin 한 번에 기동 확인
- [ ] 관리자 웹(`localhost:3000`) 로그인 → 대시보드/사용자/거래/분석 동작
- [ ] `flutter run` (에뮬레이터) → 회원가입/로그인 → 거래 등록 → 관계 집계 확인
- [ ] 백엔드 테스트 `cd backend && poetry run pytest` (32개 통과)

## Phase 2 — 계정 준비 (1~2일, 승인 대기 포함)

- [x] GitHub 계정
- [ ] 백엔드 호스팅 계정 (호스팅 선택은 Phase 3)
- [ ] Google Play Console 개발자 등록 ($25, 1회) + 신원 확인
- [ ] Google Cloud 프로젝트 (OAuth Client ID 발급용, 무료)
- [ ] (iOS 출시 시) Apple Developer Program ($99/년)

## Phase 3 — 백엔드 배포 (핵심, 약 반나절)

⚠️ **스토어 출시·앱 프로덕션 빌드보다 먼저** 완료해야 합니다. 앱이 바라볼 실제 API 주소가 여기서 나옵니다.

- [ ] 호스팅 선택: **[결정 필요]** Railway / Render / Fly.io / Cloud Run / VPS
- [ ] 관리형 PostgreSQL 프로비저닝 → `DATABASE_URL` 확보
- [ ] 프로덕션 `SECRET_KEY` 생성(개발용 `.env`와 다른 강한 랜덤값), 호스팅 환경변수로 주입 — **절대 커밋 금지**
- [ ] `CORS_ORIGINS` 를 실제 도메인으로 설정
- [ ] `alembic upgrade head` 를 배포 커맨드에 포함
- [ ] HTTPS 도메인 확인 (예: `https://api.sangsang.app`)
- [ ] 관리자 계정 생성 `poetry run python scripts/create_superuser.py`
- [ ] `docker-compose.yml` 의 개발용 소스 볼륨 마운트/`--reload` 는 프로덕션에서 제거

## Phase 4 — 프로덕션 Google 로그인 (약 1시간 + 검증 대기)

- [ ] Google Cloud Console → OAuth 동의 화면 구성(앱 이름/로고/개인정보 URL)
- [ ] Android OAuth Client ID 생성 (패키지 `com.sangbusangjo.mobile` + 릴리즈 키 SHA-1)
- [ ] 백엔드 `GOOGLE_CLIENT_ID` 환경변수 설정 (미설정 시 구글 로그인 503)
- [ ] 앱 빌드 시 `--dart-define=GOOGLE_CLIENT_ID=...` 주입

## Phase 5 — 웹사이트 + 개인정보처리방침 배포 (약 1시간) → GitHub Pages

⚠️ 개인정보처리방침 URL은 Play 심사 **필수값**입니다. 상부상조는 금융/경조사 상대방 정보를 다루므로 처리방침이 특히 중요합니다.

- [ ] `website/` 제작: index / privacy / terms / support (leeeo-fable `website/` 참고)
- [ ] 처리방침에 수집 항목(이메일·거래·상대방명), 목적, 보관/파기, 제3자 제공(Google 로그인) 명시
- [ ] 저장소 Settings > Pages > Source = GitHub Actions
- [ ] `website-deploy.yml` 워크플로 추가 → 배포 확인 (`https://leeeo.github.io/sangsang/privacy.html`)

## Phase 6 — 앱 프로덕션 빌드 준비 (약 1시간)

- [ ] `keytool` 로 업로드 키스토어 생성 + **안전한 곳에 백업** (분실 = 업데이트 불가)
- [ ] `android/key.properties` 작성 + `build.gradle.kts` 서명 설정 연결
- [ ] 프로덕션 주소로 빌드: `flutter build appbundle --release --dart-define=API_URL=https://.../api/v1 --dart-define=GOOGLE_CLIENT_ID=...`
- [ ] 앱 아이콘/스플래시/이름 최종 확인

## Phase 7 — Android 출시 (반나절 + 심사 수일)

- [ ] Play Console 앱 생성 → 설정 마법사
- [ ] 데이터 보안 양식(금융정보 수집 여부 정확히 기입), 콘텐츠 등급, 타겟 연령
- [ ] 개인정보처리방침 URL 입력 (Phase 5)
- [ ] 스토어 등록정보(설명 / 아이콘 512px / 그래픽 1024x500 / 스크린샷)
- [ ] 내부 테스트 트랙 업로드 → 실기기 로그인/거래 확인
- [ ] ⚠️ 신규 개인 개발자 계정 비공개 테스트 요건(테스터 수/기간) 확인
- [ ] 프로덕션 제출 → 심사 통과

## Phase 8 — (선택) iOS 출시

- [ ] 경로: Mac 보유(Xcode) / Mac 없음 → Codemagic (월 500분 무료)
- [ ] 번들 ID 등록 → App Store Connect 앱 생성 → App Privacy 설문 → TestFlight → 심사

## Phase 9 — 릴리즈 자동화 (약 1시간)

- [ ] `android-release.yml` 추가 (태그 `v*` push → 서명 AAB/APK 자동 빌드)
- [ ] GitHub Secrets: `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`
- [ ] 백엔드 자동 배포(호스팅사 GitHub 연동 또는 배포 워크플로) 연결
- [ ] 테스트: `git tag v1.0.1 && git push origin v1.0.1` → Actions 아티팩트 확인

## Phase 10 — 출시 후 운영

- [ ] DB 정기 백업 (사용자 재무 데이터 — 유실 방지)
- [ ] 에러/가동 모니터링, 백엔드 로그 확인
- [ ] 업데이트 절차: `pubspec.yaml` 빌드번호 ↑ → 태그 push → AAB 업로드
- [ ] 문의 대응 채널(support 이메일) 운영

---

## 절대 잊으면 안 되는 것

1. **프로덕션 SECRET_KEY** 는 개발용 `.env` 와 다른 강한 랜덤값 + 환경변수로만 주입(절대 커밋 금지).
2. **키스토어(.jks)와 비밀번호 백업** — 분실하면 앱 업데이트가 영구히 막힙니다.
3. **개인정보처리방침** — 금융/개인정보 취급 앱은 처리방침 없이는 심사 통과 불가.
4. **DB 백업** — 사용자의 실제 재무·관계 데이터라 유실 시 복구 불가.

---

## 열린 결정 (진행 전 확정 필요)

- **백엔드 호스팅처**: Railway / Render / Fly.io / Cloud Run / VPS 중?
- **출시 범위**: Android 먼저 / Android + iOS / 관리자 웹 공개배포 포함?
- **수익화**: 현재 광고·결제 코드 없음 → 무료 유틸로 출시(기본). 추가 원하면 별도 요청.
