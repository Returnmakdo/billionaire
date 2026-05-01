import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';

class AuthService {
  static User? get currentUser => sb.auth.currentUser;
  static String? get currentUserId => sb.auth.currentUser?.id;
  static Stream<AuthState> get onAuthStateChange => sb.auth.onAuthStateChange;

  static Future<void> signIn(String email, String password) async {
    await sb.auth.signInWithPassword(email: email, password: password);
  }

  /// 이메일·비밀번호 회원가입. 가입 즉시 세션 생성됨 (이메일 확인 비활성).
  /// [name]은 user_metadata에 `name`/`full_name`으로 저장.
  static Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await sb.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'full_name': name},
    );
    if (res.user == null) {
      throw Exception('회원가입에 실패했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  static Future<void> signOut() async {
    await sb.auth.signOut();
  }

  /// 가입 화면 실시간 중복 체크. 존재하면 true.
  static Future<bool> emailExists(String email) async {
    final r = await sb.rpc('check_email_exists', params: {'p_email': email});
    return r as bool;
  }

  /// 화면에 표시할 사용자 이름. user_metadata의 name → full_name → 이메일의
  /// @ 앞부분 → '사용자' 순서로 폴백.
  static String displayName() {
    final user = currentUser;
    final meta = user?.userMetadata;
    final name = (meta?['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final full = (meta?['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final email = user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return '사용자';
  }

  /// OAuth 로그인. 웹에선 현재 origin으로 리다이렉트, 모바일은 Site URL 사용.
  /// 신규 사용자면 자동 가입(트리거가 '기타' 카테고리 시드).
  static Future<void> signInWithProvider(OAuthProvider provider) async {
    await sb.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }
}
