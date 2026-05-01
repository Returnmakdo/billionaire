import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// 웹: 가능하면 Web Share API (모바일 브라우저에서 시스템 share 시트),
/// 안 되면 브라우저 다운로드. UTF-8 BOM을 prefix로 붙여 엑셀 한글 보존.
/// 반환값 true = share dialog로 처리됨 (caller가 별도 toast 띄울 필요 없음).
Future<bool> triggerCsvDownload(String csv, String filename) async {
  final bom = '﻿$csv';
  final bytes = utf8.encode(bom);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');

  // 모바일 브라우저에서만 시스템 share 시트 시도. PC에선 직접 다운로드.
  if (_isMobileBrowser() && await _trySystemShare(blob, filename)) {
    return true;
  }

  // fallback: 브라우저 다운로드.
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return false;
}

/// User-Agent 기반 모바일 브라우저 판별. PC Chrome/Edge도 share API 지원하지만
/// PC에선 다운로드가 더 자연스러우니 모바일에만 share를 띄움.
bool _isMobileBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('mobile') ||
      ua.contains('android') ||
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod');
}

/// Web Share Level 2 (files 공유). 모바일 Chrome/Safari 등 지원.
/// 미지원 환경에선 false 반환 → caller가 download fallback.
Future<bool> _trySystemShare(html.Blob blob, String filename) async {
  try {
    final navigator = html.window.navigator;
    // navigator.share + canShare 둘 다 있어야 함 (canShare는 파일 지원 체크).
    final hasShare = js_util.hasProperty(navigator, 'share');
    final hasCanShare = js_util.hasProperty(navigator, 'canShare');
    if (!hasShare || !hasCanShare) return false;

    // File 객체로 감싸기 (Blob과 다름 — Web Share는 File 요구).
    final file = js_util.callConstructor(
      js_util.getProperty(html.window, 'File'),
      [
        [blob],
        filename,
        js_util.jsify({'type': 'text/csv'}),
      ],
    );

    final shareData = js_util.jsify({
      'files': [file],
      'title': filename,
    });

    // canShare({files: [...]}) — 파일 share 가능한지 사전 검사.
    final canShare = js_util.callMethod<bool>(
      navigator,
      'canShare',
      [shareData],
    );
    if (!canShare) return false;

    await js_util.promiseToFuture<void>(
      js_util.callMethod(navigator, 'share', [shareData]),
    );
    return true;
  } catch (_) {
    // 사용자가 share 취소하거나 미지원 환경이면 그냥 false.
    return false;
  }
}
