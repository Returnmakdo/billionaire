// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// 모바일 브라우저 (Android Chrome, iOS Safari 등)면 true.
/// PC 데스크톱 브라우저는 false → 모바일 웹과 모바일 앱은 같은 UX,
/// PC만 다른 UX(직접 다운로드)로 분기하는 데 씀.
bool isMobileEnv() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('mobile') ||
      ua.contains('android') ||
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod');
}
