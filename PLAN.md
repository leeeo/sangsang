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

## Phase 1 — 로컬 검증 (약 30분)

- [ ] 실기기/에뮬레이터에서 `flutter run` (`frontend/mobile`)
- [ ] 첫 실행: 이름 입력(프로필) → 홈 진입 확인
- [ ] 기능 QA: 거래 등록 → 홈 요약/최근 거래 반영 → 관계 집계(상대방별 잔액) → 분석(월별/카테고리)
- [ ] 광고 QA: 홈 하단 **테스트 배너** 노출, 거래 저장 3회째에 전면 광고 (전부 "Test Ad" 라벨이어야 정상)
- [ ] 앱 재시작 후 데이터 유지 확인 (SQLite 영속성)

## Phase 2 — 계정 준비

- [x] Google Play Console 등록($25) — **승인 대기 중**
- [ ] AdMob 계정 생성 (무료, [admob.google.com](https://admob.google.com))

## Phase 3 — AdMob 실제 ID 발급/교체 (약 1시간)

- [ ] AdMob에 Android 앱 등록 (패키지 `com.sangbusangjo.mobile`)
- [ ] 광고 단위 2개 생성: 배너 / 전면(interstitial)
- [ ] **앱 ID**(~ 형식) 교체: `frontend/mobile/android/app/src/main/AndroidManifest.xml`
- [ ] **광고 단위 ID**(/ 형식) 2개 교체: `frontend/mobile/lib/monetization/ad_config.dart` 의 `_real...`
  - 안전장치: 교체 전엔 릴리스에서도 테스트 광고로 폴백 (계정 정지 예방)
- [ ] AdMob 콘솔 > 개인정보보호 및 메시지에서 **GDPR 메시지 게시** (앱은 UMP 동의 구현됨)
- [ ] `website/app-ads.txt` 생성 + 배포, AdMob/스토어 등록정보에 웹사이트 도메인 입력
- [ ] ⚠️ **절대 자기 광고 클릭 금지** (계정 영구 정지 사유)

## Phase 4 — 서명 키 준비 (약 30분) → [docs/03](docs/03-android-release.md)

- [ ] `keytool`로 업로드 키스토어 생성 + **안전한 곳에 백업** (분실 = 업데이트 영구 불가)
- [ ] `android/key.properties.example` → `key.properties` 복사 후 값 입력

## Phase 5 — 릴리스 빌드

- [ ] 로컬: `flutter build appbundle --release` → AAB 확인
  - 로컬 모드가 기본이라 **`--dart-define` 불필요** (API_URL/GOOGLE_CLIENT_ID는 서버 모드 전용)
- [ ] (선택) CI: GitHub Secrets 4개(`KEYSTORE_BASE64` 등) 등록 → 태그 `v1.0.0` push → 서명 AAB 아티팩트

## Phase 6 — Play Console 제출 (반나절 + 심사 수일)

- [ ] (계정 승인 후) 앱 생성 → 설정 마법사
- [ ] **데이터 안전 양식**: 광고 있음 / 광고 ID 수집=예(제3자 Google AdMob) / 앱 데이터는 기기 저장·서버 수집 없음
- [ ] 개인정보처리방침 URL: `https://leeeo.github.io/sangsang/privacy.html`
- [ ] 콘텐츠 등급, 타겟 연령(14세+ 권장)
- [ ] 스토어 등록정보: 설명 / 아이콘 512px / 그래픽 1024x500 / 스크린샷 2장+
- [ ] 내부 테스트 트랙 업로드 → 실기기 설치 → 기록/광고 동작 확인
- [ ] ⚠️ 신규 개인 계정 비공개 테스트 요건(테스터 수/기간) 해당 여부 확인
- [ ] 프로덕션 제출 → 심사 통과 → **index.html의 Play 스토어 링크 TODO 교체**

## Phase 7 — 출시 후 운영

- [ ] AdMob 수익/eCPM 모니터링, 지급 정보(기준 $100) 설정
- [ ] 리뷰 대응, 크래시 모니터링(Play Console Vitals)
- [ ] 업데이트 절차: `pubspec.yaml` version `+빌드번호` ↑ → 태그 push → AAB 업로드

---

## 향후 로드맵 (v1.1+)

1. **로컬 백업/내보내기(CSV)** — "앱 삭제 = 데이터 소실" 보완. 우선순위 높음.
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
