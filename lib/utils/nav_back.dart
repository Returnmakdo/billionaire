import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'browser_back_stub.dart'
    if (dart.library.html) 'browser_back_web.dart';

/// 뒤로가기 통일 핸들러.
/// - 웹: 브라우저 history.back() — GoRouter가 url strategy로 history에 entry를
///       push하므로 정확히 이전 path로 돌아감.
/// - 모바일 native: navigator stack pop, 안 되면 fallback path로 go.
void goBackOr(BuildContext context, String fallback) {
  if (tryBrowserBack()) return;
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go(fallback);
  }
}
