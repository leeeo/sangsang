import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<PlatformFile?> pickImportFile(List<String> extensions) async =>
    (await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: false,
      withReadStream: true,
    ))?.files.single;

Future<Uint8List> readImportFile(
  PlatformFile file,
  int maxBytes,
  String limitMessage,
) async {
  if (file.size > maxBytes) throw FormatException(limitMessage);
  final stream = file.readStream;
  if (stream == null) throw const FormatException('파일을 열 수 없어요.');
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > maxBytes) {
      throw FormatException(limitMessage);
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
