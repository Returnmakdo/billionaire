// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// 웹: 브라우저 history.back() 호출. GoRouter가 url strategy로 history에
/// entry를 push하므로 정확히 이전 path로 돌아감.
bool tryBrowserBack() {
  html.window.history.back();
  return true;
}
