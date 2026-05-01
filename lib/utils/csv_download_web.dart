import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// 웹에서 CSV 문자열을 Blob으로 묶어 브라우저 다운로드 트리거.
/// UTF-8 BOM을 prefix로 붙여서 엑셀이 한글 깨지지 않게 함.
void triggerCsvDownload(String csv, String filename) {
  final bytes = utf8.encode('﻿$csv');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
