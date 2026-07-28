import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Compresses photos before Vertex/Gemini upload to cut tokens and avoid quotas.
///
/// Returns the original path if compression is unnecessary or fails.
Future<String> compressImageForUpload(
  String filePath, {
  int quality = 60,
  int maxWidth = 800,
  int maxHeight = 800,
}) async {
  final source = File(filePath);
  if (!await source.exists()) return filePath;

  final ext = p.extension(filePath).toLowerCase();
  if (ext == '.pdf') return filePath;

  try {
    // Already small enough — skip work to avoid needless recompression.
    final bytes = await source.length();
    if (bytes > 0 && bytes <= 350 * 1024) return filePath;

    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      'pha_upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final compressed = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) return filePath;
    final out = File(compressed.path);
    if (!await out.exists() || await out.length() == 0) return filePath;
    return compressed.path;
  } catch (_) {
    return filePath;
  }
}
