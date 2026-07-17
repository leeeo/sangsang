# 03. Android 출시 — 서명 & 릴리스 자동화

상부상조 앱(`frontend/mobile`, 패키지 `com.sangbusangjo.mobile`)의 서명·빌드·릴리스 절차입니다. [PLAN.md](../PLAN.md)의 **Phase 6 / Phase 9**에 해당합니다.

> 선행: **Phase 3(백엔드 배포)**로 API 주소가 확정돼 있어야 합니다 (`--dart-define=API_URL`).

## 1. 업로드 키스토어 생성 (최초 1회)
```bash
cd frontend/mobile/android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
⚠️ **`upload-keystore.jks` 와 비밀번호를 안전한 곳에 백업하세요. 분실하면 앱 업데이트가 영구히 막힙니다.**

## 2. key.properties 작성 (로컬 서명용)
`android/key.properties.example` 를 복사해 `android/key.properties` 생성 후 값 입력:
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```
> `key.properties` 와 `*.jks` 는 `.gitignore` 처리되어 커밋되지 않습니다.
> [build.gradle.kts](../frontend/mobile/android/app/build.gradle.kts)는 이 파일이 있으면 **릴리스 서명**, 없으면 **debug 서명**으로 폴백합니다(로컬 `flutter run --release` 유지).

## 3. 로컬 릴리스 빌드
```bash
cd frontend/mobile
flutter build appbundle --release \
  --dart-define=API_URL=https://<railway 도메인>/api/v1 \
  --dart-define=GOOGLE_CLIENT_ID=<구글 클라이언트 ID>
```
> `--dart-define` 없이 빌드하면 앱이 `localhost` 를 바라봐 실기기/프로덕션에서 동작하지 않습니다.

## 4. CI 자동 릴리스 (태그 기반)
[.github/workflows/android-release.yml](../.github/workflows/android-release.yml)이 `v*` 태그 push 시 서명 AAB/APK 를 빌드합니다.

**Settings > Secrets and variables > Actions**:
- **Secrets**: `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`
- **Variables**: `API_URL`(=`https://<railway>/api/v1`), `GOOGLE_CLIENT_ID`

키스토어 base64 인코딩 (Windows PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Content keystore.b64
```

릴리스 실행:
```bash
git tag v1.0.0 && git push origin v1.0.0
```
→ Actions 에서 `sangsang-aab` / `sangsang-apk` 아티팩트 다운로드.

## 5. Play Console 업로드
AAB 를 내부 테스트 트랙 업로드 → 확인 후 프로덕션 승격. 개인정보처리방침 URL(Phase 5, [docs/02](02-website-deploy-pages.md)) 입력이 필수입니다.
