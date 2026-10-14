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

## 웹판 차이

- 광고(AdMob)는 웹에서 동작하지 않는다(코드가 웹에서 no-op).
- 백업 내보내기는 파일 내려받기, 가져오기는 파일 선택(내용만 읽음)으로 동작한다.
- 브라우저 저장소를 지우거나 다른 브라우저·기기에서 열면 데이터가 보이지 않는다. 백업 JSON으로 옮긴다.
