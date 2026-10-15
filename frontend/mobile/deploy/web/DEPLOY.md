# 상부상조 웹판 배포 (sangsang.leeeo.app)

로컬 모드 앱을 Flutter web으로 빌드해 정적 파일로 제공한다. 서버·계정·광고 없음. 데이터는 각 브라우저(IndexedDB의 SQLite WASM)에만 저장된다.

- 공개 주소: https://sangsang.leeeo.app (Cloudflare Tunnel `leeeo-vm`, 설정 원본은 leeeo-company `deploy/cloudflared/`)
- VM: `/home/leeeo/apps/sangsang-web` (`compose.yaml`, `nginx.conf`, `html/` = 빌드 결과), 포트 `127.0.0.1:8790`

## 배포·업데이트 (이 PC에서)

```sh
cd frontend/mobile
flutter build web --release
tar -C build/web -cf - . | ssh leeeo@100.80.181.92 "rm -rf ~/apps/sangsang-web/html.new && mkdir -p ~/apps/sangsang-web/html.new && tar -x -C ~/apps/sangsang-web/html.new && cd ~/apps/sangsang-web && rm -rf html.old && (mv html html.old || true) && mv html.new html"
scp deploy/web/compose.yaml deploy/web/nginx.conf leeeo@100.80.181.92:apps/sangsang-web/
ssh leeeo@100.80.181.92 "cd ~/apps/sangsang-web && docker compose up -d && docker compose restart"
```

롤백은 VM에서 `html.old`를 `html`로 되돌린다.

캐시: `nginx.conf`는 정적 파일에 7일 캐시를 주고 Cloudflare가 그대로 엣지에 든다. `main.dart.js`는 이름이 고정이라 `web/flutter_bootstrap.js`가 빌드마다 바놀는 `?v=<서비스워커 버전>`을 붙여 로드한다(10-15 추가, 그 전 배포는 엣지에 7일간 예전 파일이 남았다). 진입 파일(index.html·flutter_bootstrap.js 등)은 `no-store`다. `no-cache`로 두면 Cloudflare가 `.js`를 엣지에 넣고 브라우저 TTL을 4시간으로 덮어써 새 릴리스가 최대 4시간 늦게 보인다(10-15 확인). `assets/`(트리쉐이킹된 아이콘 폰트·매니페스트)도 고정 이름이라 `no-store`다 — 10-15 배포 때 엣지에 남은 예전 아이콘 폰트 때문에 새 화면의 아이콘이 비어 보였다. 이미 엣지에 들어간 파일은 TTL이 끝나거나 Cloudflare 대시보드에서 캐시를 비워야 바뀜다. `canvaskit/`는 Flutter SDK를 올릴 때만 바뀜니 그때는 Cloudflare 대시보드에서 캐시를 비운다.

## 웹판 차이

- 광고(AdMob)는 웹에서 동작하지 않는다(코드가 웹에서 no-op).
- 백업 내보내기는 파일 내려받기, 가져오기는 파일 선택(내용만 읽음)으로 동작한다.
- 브라우저 저장소를 지우거나 다른 브라우저·기기에서 열면 데이터가 보이지 않는다. 백업 JSON으로 옮긴다.
