// Browser download on web; unsupported elsewhere (mobile shares a temp file instead).
export 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';
