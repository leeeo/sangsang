# 상부상조 출시 실행 플랜

> **v1 전략: 로컬 우선(서버 없음) + AdMob 광고** — 가볍게 출시하고, 서버·계정은 향후 도입한다.
> 앱은 `APP_MODE`(기본 `local`) 플래그로 동작하며, 기존 서버 연동 코드(FastAPI 백엔드 + dio 경로)는
> 전부 보존되어 `--dart-define=APP_MODE=server` 빌드로 언제든 되살릴 수 있다.

> 사용법: 한 단계씩 진행하며 `[ ]`를 `[x]`로 바꿔 기록하세요. 위에서 아래가 의존성 순서입니다.

---

## 현재 상태 요약

| 영역 | 상태 |
|---|---|
| 앱: 로컬 모드(SQLite) + 광고(배너/전면) | ✅ 완료 (analyze 0건 · 테스트 12/12 · 릴리스 APK 54.4MB 빌드 검증) |
| 웹사이트 + 개인정보처리방침(로컬+AdMob 기준) | ✅ 라이브 — [leeeo.github.io/sangsang](https://leeeo.github.io/sangsang/) |
| CI · Android 서명 배선 · 태그 릴리스 워크플로 | ✅ 완료 |
| Google Play Console 개발자 계정 | 🔄 등록 완료, 승인 대기 |
| AdMob 계정 + 실제 광고 ID | ⬜ 미완 (현재 테스트 ID — 교체 전 수익 0) |
| 업로드 키스토어 + 스토어 등록 | ⬜ 미완 |

---

## Phase 1 — 로컬 검증 ✅ 완료 (2026-07-21, 실기기 debug APK)

- [x] 실기기 설치 (debug APK — 테스트 광고 버전)
- [x] 첫 실행: 이름 입력(프로필) → 홈 진입 확인
- [x] 기능 QA: 거래 등록 → 홈 반영 → 관계 집계 → 분석
- [x] 광고 QA: 테스트 배너 + 전면 광고
- [x] 앱 재시작 후 데이터 유지 확인

## Phase 2 — 계정 준비

- [x] Google Play Console 등록($25) — **승인 완료**
- [x] AdMob 계정 생성 (무료, [admob.google.com](https://admob.google.com))

## Phase 3 — AdMob 실제 ID 발급/교체 (약 1시간)

- [x] AdMob에 Android 앱 등록 (앱 이름 `상부상조`)
- [x] 광고 단위 2개 생성: 배너(`/7971424121`) / 전면(`/4350643231`)
- [x] **앱 ID** 교체: AndroidManifest.xml (`ca-app-pub-9901401078434900~9591627554`)
- [x] **광고 단위 ID** 2개 교체: `ad_config.dart` (Android — iOS는 출시 시)
- [ ] AdMob 콘솔 > 개인정보보호 및 메시지에서 **GDPR 메시지 게시** (앱은 UMP 동의 구현됨)
- [x] `app-ads.txt` 배포 — ⚠️ github.io는 Public Suffix라 **루트 도메인**(`leeeo.github.io/app-ads.txt`, 유저 사이트 저장소)에 있어야 크롤링됨. 프로젝트 사이트에도 사본 유지.
- [ ] 스토어 등록정보의 웹사이트 항목에 `https://leeeo.github.io/sangsang/` 입력 (크롤러가 루트 도메인 추출)
- [ ] ⚠️ **절대 자기 광고 클릭 금지** (계정 영구 정지 사유) — 실ID 적용된 새 빌드부터 실제 광고 노출됨

## Phase 4 — 서명 키 준비 ✅ 완료 (2026-07-21)

- [x] `keytool`로 업로드 키스토어 생성
- [x] `key.properties` 작성 (gitignore 확인됨)
- [ ] ⚠️ **키스토어(.jks)+비밀번호 백업** — 아직 안 했다면 지금 (클라우드/USB 등 2곳 이상)

## Phase 5 — 릴리스 빌드 ✅ 완료 (2026-07-21)

- [x] `flutter build appbundle --release` → **app-release.aab 52.2MB, 서명 CN=Eojin Lee 확인**
- [ ] (선택) CI: GitHub Secrets 4개(`KEYSTORE_BASE64` 등) 등록 → 태그 `v1.0.0` push → 서명 AAB 아티팩트

## Phase 6 — Play Console 제출 ✅ 심사 제출 완료 (2026-07-21)

- [x] 앱 생성 (`상부상조 - 경조사비 관리`, 한국어, 무료)
- [x] 개인정보처리방침 URL / 앱 액세스 / 광고 포함=예 / 광고 ID 사용=예
- [x] 콘텐츠 등급(전체이용가) / 타겟층(18+) / 데이터 안전(기기ID·광고만 수집)
- [x] 스토어 등록정보: 설명 + 아이콘 512 + 피처 그래픽 + 스크린샷 4장 (`store_assets/`)
- [x] 비공개 테스트(알파) 트랙에 AAB 업로드 + 테스터 목록 + 국가(대한민국)
- [x] **변경사항 전송 → 구글 심사 중** (첫 제출 보통 1~7일)

## Phase 6.5 — 심사 통과 후 (다음 할 일)

- [ ] **Android 개발자 인증 — 패키지 등록 확인**: Play Console 홈 > Android 개발자 인증 페이지에서 `com.sangbusangjo.mobile` 이 **"등록됨"** 인지 확인 (Play 앱 서명 사용 → 자동 등록됨. 마감 2026-09-30). Play 외부 배포 안 하므로 "추가 키" 항목은 무시.
- [ ] Play 자동 업로드 파이프라인 활성화 (선택) → [docs/05](docs/05-play-auto-upload.md) (서비스 계정 + PLAY_SERVICE_ACCOUNT_JSON 시크릿)
- [ ] 테스터 참여 링크로 본인 폰 설치 확인 (⚠️ 실광고 버전 — 절대 클릭 금지)
- [ ] AdMob 콘솔에서 앱을 스토어 등록정보와 연결 (심사 통과 후 가능)
- [ ] AdMob **GDPR 메시지 게시** 확인 (개인정보보호 및 메시지)
- [ ] 테스터 모집: 참여 링크 지인 공유 (콘솔 요구 인원 충족, 통상 12명·14일 유지)
- [ ] 14일 경과 후 **프로덕션 액세스 신청** → 승인 → 프로덕션 출시
- [ ] 출시 후: index.html Play 스토어 링크 교체 + `website/sitemap` 확인

## Phase 7 — 출시 후 운영

- [ ] AdMob 수익/eCPM 모니터링, 지급 정보(기준 $100) 설정
- [ ] 리뷰 대응, 크래시 모니터링(Play Console Vitals)
- [ ] 업데이트 절차: `pubspec.yaml` version `+빌드번호` ↑ → 태그 push → AAB 업로드

---

## 향후 로드맵 (v1.1+)

1. ✅ **로컬 백업/복원(JSON) + CSV 내보내기** — 구현 완료(v1.1, 홈 > 백업/복원). "앱 삭제 = 데이터 소실" 리스크 해소.
   - ⚠️ v1.1을 실제 출시할 때: 스토어 설명·[website FAQ](website/support.html)의 "백업 준비 중" 문구를 "지원함"으로 갱신.
2. **서버 도입** — 기존 FastAPI 백엔드/관리자 웹은 코드 보존됨.
   - 배포: [docs/01 Railway 가이드](docs/01-backend-deploy-railway.md) 그대로 유효
   - 앱: `--dart-define=APP_MODE=server` 빌드로 기존 로그인/서버 경로 활성화
   - 마이그레이션: 로컬 SQLite 스키마가 백엔드 API와 필드 호환 → 로그인 후 업로드 동기화 구현
   - 프로덕션 Google OAuth(Client ID + SHA-1)도 이 시점에
3. **유료 전환 옵션** — "광고 제거" IAP (leeeo-fable `iap_manager.dart` 패턴 이식)

---

## 절대 잊으면 안 되는 것

1. **키스토어(.jks)와 비밀번호 백업** — 분실하면 앱 업데이트가 영구히 막힌다.
2. **광고 ID 교체 없이 출시하면 수익 0원** — 안전장치가 테스트 광고로 폴백시킨다 (`ad_config.dart`).
3. **자기 광고 클릭 금지** — AdMob 계정 영구 정지 사유.
4. **앱 삭제 = 데이터 소실** — 처리방침/FAQ에 고지됨. v1.1 백업 기능으로 보완 예정.

---

## 확정된 결정 기록

- **아키텍처**: v1 로컬 우선(서버 없음, 기기 내 SQLite). 서버 코드는 보존, `APP_MODE`로 전환.
- **수익화**: AdMob 광고 (배너: 홈 하단 / 전면: 거래 저장 3회마다·60초 쿨다운). ~~무광고~~ → 광고로 변경(2026-07-20).
- **출시 범위**: Android 먼저. iOS는 이후(ATT 구현 필요).
- **백엔드 호스팅(향후)**: Railway ([docs/01](docs/01-backend-deploy-railway.md)).
