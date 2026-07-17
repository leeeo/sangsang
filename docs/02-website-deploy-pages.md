# 02. 웹사이트 배포 — GitHub Pages

상부상조 마케팅/법적고지 웹사이트(`website/`)를 **GitHub Pages**로 배포하는 절차입니다. [PLAN.md](../PLAN.md)의 **Phase 5**에 해당합니다. 개인정보처리방침 URL은 Google Play 심사 **필수값**이므로 스토어 제출 전에 완료해야 합니다.

## 1. 개인정보 채우기 (배포 전 필수)
`website/` 안의 **TODO 플레이스홀더**를 실제 값으로 교체하세요(총 16곳):
- `<!-- TODO: 운영자명 -->` — 개인정보 보호책임자/운영자 이름 (privacy.html, terms.html)
- `<!-- TODO: 문의 이메일 -->` — 실제 문의·삭제요청 접수 이메일 (privacy/terms/support) — **Play 심사 필수**
- `<!-- TODO: 실제 Play 스토어 링크 -->` — 앱 등록 후 스토어 URL (index.html)

> ⚠️ 이 값들은 공개 웹사이트에 노출되는 개인정보이므로, 공개용 이메일/표기명을 사용하세요.

## 2. Pages 소스 설정 (최초 1회)
저장소 **Settings > Pages > Build and deployment > Source = GitHub Actions**

## 3. 배포
- `website/` 변경 후 `main`에 push → `Deploy Website` 워크플로가 자동 실행
- 또는 Actions 탭에서 수동 실행(`workflow_dispatch`)

## 4. 확인
| URL | 용도 |
|---|---|
| `https://leeeo.github.io/sangsang/` | 랜딩 페이지 |
| `https://leeeo.github.io/sangsang/privacy.html` | **Play Console 개인정보처리방침 URL에 입력** |
| `https://leeeo.github.io/sangsang/terms.html` | 이용약관 |
| `https://leeeo.github.io/sangsang/support.html` | 지원/문의 |

## 참고
- 프로젝트 사이트라 base 경로가 `/sangsang/` 입니다. 페이지 간 링크는 상대경로라 정상 동작합니다.
- 커스텀 도메인을 쓰려면 `website/CNAME` 파일을 추가하고 Pages 설정에서 도메인을 지정하세요.
