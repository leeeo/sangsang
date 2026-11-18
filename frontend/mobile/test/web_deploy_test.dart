import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _site = 'https://sangsang.leeeo.app';

String _read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('web robots.txt is a plain-text rule file that names the sitemap', () {
    final robots = _read('web/robots.txt');
    expect(robots.contains('<'), isFalse);
    expect(robots.split('\n'), containsAll(['User-agent: *', 'Sitemap: $_site/sitemap.xml']));
    expect(_read('web/sitemap.xml'), contains('<loc>$_site/</loc>'));
  });

  test('web nginx answers 404 for unknown paths instead of the app shell', () {
    final conf = _read('deploy/web/nginx.conf');
    expect(conf, matches(RegExp(r'location / \{\s+try_files \$uri \$uri/ =404;\s+\}')));
    expect(conf, isNot(matches(RegExp(r'try_files[^;]*index\.html'))));
    // nginx's own 404 page prints the nginx version unless server_tokens is off.
    expect(conf, matches(RegExp(r'^ {4}server_tokens off;$', multiLine: true)));
  });

  test('the app keeps hash URLs, so no route depends on a server fallback', () {
    // usePathUrlStrategy()/setUrlStrategy() would turn /home into a server request: nginx would need the fallback back.
    final sources = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in sources) {
      expect(file.readAsStringSync(), isNot(matches(RegExp('usePathUrlStrategy|setUrlStrategy'))), reason: file.path);
    }
  });

  test('web nginx still sets the security headers on the server block', () {
    final names = RegExp(r'^ {4}add_header (\S+) ', multiLine: true).allMatches(_read('deploy/web/nginx.conf')).map((m) => m.group(1));
    expect(names, [
      'Cache-Control',
      'Content-Security-Policy',
      'X-Content-Type-Options',
      'X-Frame-Options',
      'Referrer-Policy',
      'Permissions-Policy',
      'Strict-Transport-Security',
    ]);
  });
}
