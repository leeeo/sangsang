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

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion,
  },
  config,
});
