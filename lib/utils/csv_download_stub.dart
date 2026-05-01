import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 비-웹 플랫폼(Android/iOS): share_plus로 임시 파일 공유.
/// 사용자가 카카오톡/메모/구글드라이브/메일 등으로 저장 가능.
Future<void> triggerCsvDownload(String csv, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path, name: filename, mimeType: 'text/csv')]);
}
