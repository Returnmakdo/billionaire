import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 비-웹 플랫폼(Android/iOS): share_plus로 임시 파일 공유.
/// 반환값 true = share dialog로 처리됨 (caller가 별도 toast 띄울 필요 없음).
Future<bool> triggerCsvDownload(String csv, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path, name: filename, mimeType: 'text/csv')]);
  return true;
}
