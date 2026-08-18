# 06. 아이폰에 설치하기 (사이드로드 · Apple 유료 계정 없이)

Play 심사를 기다리는 동안 **아이폰에서 직접 써보기 위한** 경로입니다. Apple Developer Program($99/년) 없이, 무료 Apple ID만으로 설치합니다.

> 왜 이렇게 하나: iOS 빌드는 macOS에서만 됩니다. 개발 PC가 Windows라 로컬 빌드가 불가능해, GitHub Actions의 macOS 러너가 대신 빌드합니다 (저장소가 public이라 **무료**). CI는 **미서명 IPA**만 만들고, 서명은 PC의 Sideloadly가 본인 Apple ID로 처리합니다.
> 빌드 워크플로: [ios-release.yml](../.github/workflows/ios-release.yml)

## 무료 Apple ID의 제약 (먼저 알고 시작)

| 항목 | 제한 |
|---|---|
| 앱 유효기간 | **7일** — 만료되면 실행 안 됨. PC에 연결해 재서명하면 다시 7일 |
| 동시 사이드로드 앱 수 | 3개 |
| 신규 App ID 발급 | 7일당 10개 |

유료 계정($99/년)이면 유효기간이 1년으로 늘고 TestFlight 무선 배포가 가능합니다. 계속 쓸 것 같으면 그때 전환하세요.

---

## 1. 준비물 (최초 1회, 약 15분)

winget으로 한 번에 깔 수 있습니다. **iCloud만 관리자 권한(UAC)이 필요**합니다.

```powershell
winget install --id Apple.iTunes                    # Apple Application Support 포함
winget install --id Apple.AppleMobileDeviceSupport  # ★ iTunes가 안 깔아주는 경우가 있음 - 별도 설치 필수
winget install --id iOSGods.Sideloadly
# iCloud는 무인설치가 권한 부족(1603)으로 실패하므로 관리자 권한으로 직접 실행
Start-Process "$env:TEMP\iCloudSetup.exe" -Verb RunAs -Wait -ArgumentList "/quiet","/norestart"
```

1. **iTunes**와 **iCloud** — 반드시 [apple.com](https://www.apple.com/itunes/download/) 에서 받은 데스크톱 버전(winget의 `Apple.iTunes` / `Apple.iCloud` 가 이 버전입니다). **Microsoft Store 버전은 동작하지 않습니다.**
   - 설치 확인: `Get-Service Apple*` 에 **Apple Mobile Device Service** 가 `Running` 이어야 아이폰이 USB로 잡힙니다.
   - Apple ID 인증에는 iCloud의 `C:\Program Files (x86)\Common Files\Apple\Internet Services\AOSKit.dll` 이 필요합니다.
2. **Sideloadly** — 설치 경로는 `%LOCALAPPDATA%\Sideloadly\sideloadly.exe` 입니다.
3. **USB 케이블** + 아이폰. 연결 후 아이폰에 뜨는 **"이 컴퓨터를 신뢰하시겠습니까?"** → 신뢰.
4. **Apple ID** — 본인 계정. 2단계 인증이 켜져 있으면 설치 중 인증 코드를 물어봅니다.

## 2. IPA 내려받기

항상 최신 빌드가 올라오는 **고정 주소**입니다. 로그인 없이 받아집니다.

```
https://github.com/leeeo/sangsang/releases/download/ios-latest/sangbusangjo-ios-unsigned.ipa
```

(릴리즈 페이지: [releases/tag/ios-latest](https://github.com/leeeo/sangsang/releases/tag/ios-latest))

## 3. 서명 + 설치 (약 3분)

1. Sideloadly 실행 → `iDevice:` 칸에 아이폰이 잡혔는지 확인
2. 왼쪽 칸에 내려받은 `.ipa` 파일을 드래그 (또는 `sideloadly.exe "경로\앱.ipa"` 로 실행하면 자동 로드)
3. **Apple ID** 칸에 본인 Apple ID 입력
4. **Start** → 비밀번호(+2단계 인증 코드) 입력
5. 진행바가 `Done` 이 되면 홈 화면에 **상부상조** 아이콘 생성

> ⚠️ **첫 실행은 반드시 "관리자 권한으로 실행"** 하세요. 그냥 실행하면
> `Sideloadly needs administrator permission in order to setup local anisette (CoreFP key: Access is denied)`
> 경고가 뜨고 Apple ID 로그인이 실패합니다. anisette 키 생성은 **최초 1회만** 관리자 권한이 필요하고, 이후엔 일반 실행으로 충분합니다.

## 4. 개발자 신뢰 (최초 1회)

설치 직후 앱을 누르면 "신뢰하지 않은 개발자" 경고가 뜹니다.

**설정 > 일반 > VPN 및 기기 관리 > (본인 Apple ID) > 신뢰**

이후 정상 실행됩니다.

---

## 7일마다 재서명하기

만료되면 앱이 실행되지 않습니다(데이터는 남아 있음). **2~3번 과정을 그대로 반복**하면 됩니다 — 같은 번들 ID(`com.sangbusangjo.mobile`)로 덮어 설치되므로 **기존 데이터는 유지**됩니다.

> ⚠️ 그래도 재서명 전에 앱의 **홈 > 백업/복원 > 백업 파일 내보내기**로 JSON을 한 번 빼두는 걸 권합니다. 번들 ID가 바뀌거나 앱을 지우면 로컬 SQLite 데이터가 함께 사라집니다.

**케이블 연결이 귀찮으면**: [AltStore](https://altstore.io) 또는 [SideStore](https://sidestore.io) 를 쓰면 Wi-Fi로 자동 재서명됩니다. 설정은 더 번거롭지만 이후 7일 갱신이 자동입니다.

## 코드를 고친 뒤 새 IPA 받기

`frontend/mobile/` 아래를 수정해 `main` 에 push하면 워크플로가 자동으로 돌고, 위 고정 URL의 파일이 **새 빌드로 교체**됩니다. 다시 받아서 3번을 반복하면 업데이트 완료입니다.

수동으로 돌리려면: 저장소 **Actions > iOS Unsigned IPA > Run workflow**.

빌드 시간은 보통 8~15분입니다.

---

## 알아둘 것

- **광고는 테스트 광고입니다.** iOS AdMob 앱을 아직 등록하지 않아 [Info.plist](../frontend/mobile/ios/Runner/Info.plist)의 앱 ID와 [ad_config.dart](../frontend/mobile/lib/monetization/ad_config.dart)가 모두 Google 공식 테스트 ID로 동작합니다. 도그푸딩 중 광고를 눌러도 **계정 정지 위험이 없습니다**.
- **서버가 필요 없습니다.** v1은 로컬 우선(`APP_MODE=local`)이라 기기 내 SQLite만 씁니다. 로그인 없이 바로 사용 가능합니다.
- **이 IPA로는 App Store에 못 올립니다.** 미서명 사이드로드 전용입니다. iOS 정식 출시는 유료 계정 + 실제 AdMob iOS ID + ATT 프롬프트 구현이 선행돼야 합니다 ([PLAN.md](../PLAN.md) 로드맵 참고).
