{{flutter_js}}
{{flutter_build_config}}

// main.dart.js keeps a fixed name, so Cloudflare and browsers would serve a 7-day-old copy
// after a release. Appending the per-build service worker version makes each release a new URL.
const serviceWorkerVersion = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?v=${serviceWorkerVersion}`;
  }
}

// Assets (fonts, AssetManifest) also have fixed names: behind the CDN (https) they load from a per-release
// /r/<version>/ prefix that nginx maps back to /assets/; local `flutter run` (http) keeps the default base.
const config = location.protocol === 'https:' ? { assetBase: `/r/${serviceWorkerVersion}/` } : {};

const startup = document.getElementById('startup');
const retry = document.getElementById('startup-retry');
retry?.addEventListener('click', () => location.reload());

function showStartupError() {
  const status = document.getElementById('startup-status');
  if (status) status.textContent = '기록장을 열지 못했어요. 인터넷 연결을 확인하고 다시 열어 주세요.';
  if (retry) retry.hidden = false;
}

// The engine loader does not reject its promise for a failed script request.
window.addEventListener('error', (event) => {
  if (event.target instanceof HTMLScriptElement || event instanceof ErrorEvent) {
    showStartupError();
  }
}, true);

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion,
  },
  config,
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const appRunner = await engineInitializer.initializeEngine(config);
      await appRunner.runApp();
      startup?.remove();
    } catch (_) {
      showStartupError();
    }
  },
}).catch(showStartupError);
