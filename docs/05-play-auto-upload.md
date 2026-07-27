# 05. Play 자동 업로드 파이프라인 (서비스 계정)

`git tag v1.0.1 && git push origin v1.0.1` 한 번으로 **서명 AAB 빌드 → Play 트랙 자동 업로드**까지 되게 하는 일회성 셋업입니다. ([android-release.yml](../.github/workflows/android-release.yml))

> 전제: **첫 AAB는 이미 콘솔에서 수동 업로드 완료**(2026-07-21). Play Developer API는 첫 수동 업로드 이후에만 동작하므로 자격이 생겼습니다.

## 1. GCP 서비스 계정 + 키 (약 5분)
1. [console.cloud.google.com](https://console.cloud.google.com) → 프로젝트 생성(또는 기존)
2. **API 및 서비스 > 라이브러리** → **Google Play Android Developer API** 사용 설정
3. **IAM 및 관리자 > 서비스 계정** → **서비스 계정 만들기** (이름 예: `play-ci`)
4. 만든 서비스 계정 → **키 탭 > 키 추가 > 새 키 > JSON** → 다운로드 (이 JSON을 4번에서 사용)
   - ⚠️ 이 JSON은 비밀. 저장소·문서에 절대 커밋 금지.

## 2. Play Console에 서비스 계정 권한 부여 (약 3분)
1. [Play Console](https://play.google.com/console) → **사용자 및 권한** → **새 사용자 초대**
2. 이메일: 서비스 계정 이메일(`play-ci@...gserviceaccount.com`) 입력
3. 앱 권한: **상부상조** 선택 → 다음 권한 부여:
   - 「테스트 트랙에 대한 출시 관리」 (릴리스)  ← 최소
   - 「프로덕션 출시 관리」 (프로덕션 자동 배포까지 원하면)
4. 초대 → 서비스 계정이 목록에 뜨면 완료

## 3. GitHub Secret 등록 (1분)
저장소 **Settings > Secrets and variables > Actions > New repository secret**
- 이름: `PLAY_SERVICE_ACCOUNT_JSON`
- 값: 1번에서 받은 **JSON 파일 전체 내용** 붙여넣기

> (서명 시크릿 4개 `KEYSTORE_BASE64`/`STORE_PASSWORD`/`KEY_PASSWORD`/`KEY_ALIAS` 도 아직 안 넣었으면 함께 등록 → [docs/03](03-android-release.md))

## 4. 실행
```bash
# pubspec.yaml version 을 올리고 싶으면 먼저 수정 (versionName). versionCode는 자동 증가.
git tag v1.0.1
git push origin v1.0.1
```
→ Actions 탭에서 `Android Release` 실행 확인 → Play Console **테스트 > 내부 테스트**에 새 버전 도착.

## 트랙 바꾸기 (필요 시)
[android-release.yml](../.github/workflows/android-release.yml) 의 `track:` 값:
- `internal` (기본) — 즉시·안전, 파이프라인 검증용
- `production` — 출시 후. 단계적 출시는 `status: inProgress` + `userFraction: '0.2'`

## 참고
- `PLAY_SERVICE_ACCOUNT_JSON` 시크릿이 없으면 업로드 단계는 **자동 건너뜀** → 태그 push해도 빌드/아티팩트만 생성(안전).
- 버전 코드 충돌("이미 사용된 버전 코드") 시: 워크플로를 한 번 더 실행하거나 pubspec 빌드번호를 올리세요.
