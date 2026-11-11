import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final http.Client _client = http.Client();
final Map<String, Future<String>> _downloads = {};

Future<String?> getOrDownload(String url) async {
  final directory = await getApplicationSupportDirectory();
  final cacheDirectory = Directory(path.join(directory.path, 'recitation_audio'));
  await cacheDirectory.create(recursive: true);

  final fileName = _fileNameForUrl(url);
  final filePath = path.join(cacheDirectory.path, fileName);
  final cachedFile = File(filePath);
  if (await cachedFile.exists()) return filePath;

  final pendingDownload = _downloads[url];
  if (pendingDownload != null) return pendingDownload;

  final download = _download(url, filePath);
  _downloads[url] = download;
  try {
    return await download;
  } finally {
    _downloads.remove(url);
  }
}

Future<String> _download(String url, String filePath) async {
  final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('Audio download failed (${response.statusCode})', uri: Uri.parse(url));
  }

  final tempFile = File('$filePath.part');
  try {
    await tempFile.writeAsBytes(response.bodyBytes, flush: true);
    await tempFile.rename(filePath);
    return filePath;
  } catch (_) {
    if (await tempFile.exists()) await tempFile.delete();
    rethrow;
  }
}

String _fileNameForUrl(String url) {
  final uri = Uri.parse(url);
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  final folder = segments.length >= 2 ? segments[segments.length - 2] : 'recitation';
  final file = segments.isNotEmpty ? segments.last : '${url.hashCode}.mp3';
  return '${folder}_$file';
}