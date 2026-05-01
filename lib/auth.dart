import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';

class AuthService {
  static User? get currentUser => sb.auth.currentUser;
  static String? get currentUserId => sb.auth.currentUser?.id;
  static Stream<AuthState> get onAuthStateChange => sb.auth.onAuthStateChange;

  /// 비밀번호 재설정 메일 링크로 들어왔을 때 true. 라우터가 /reset-password로
  /// 강제 이동시킬 때 참고. 새 비번 변경 후 false로 리셋.
  static final ValueNotifier<bool> recoveryMode = ValueNotifier(false);

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

  /// 사용자 이름 변경 — user_metadata의 name/full_name 갱신.
  static Future<void> updateName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw Exception('이름은 비울 수 없어요');
    await sb.auth.updateUser(
      UserAttributes(data: {'name': clean, 'full_name': clean}),
    );
  }

  /// 비밀번호 변경. OAuth 가입자에겐 의미 없음 (Supabase가 비번 없는 계정에 새로
  /// 비번을 세팅하긴 하지만 OAuth 흐름엔 안 쓰임).
  static Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 8) {
      throw Exception('비밀번호는 8자 이상이어야 해요');
    }
    await sb.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// 본인 계정 삭제. delete_my_account RPC가 auth.users에서 본인 행 삭제 →
  /// ON DELETE CASCADE로 모든 데이터 자동 정리. 이후 onAuthStateChange가
  /// signedOut으로 떨어져 자동 로그인 화면으로 이동.
  static Future<void> deleteAccount() async {
    await sb.rpc('delete_my_account');
    await sb.auth.signOut();
  }

  /// 비밀번호 재설정 메일 발송. 로그인 화면 "비밀번호 잊으셨나요?"용.
  /// redirectTo는 root origin만 — Supabase Redirect URLs 화이트리스트랑 매칭
  /// 안 되면 Site URL(prod)로 fallback 됨. 클릭 후 우리 앱이 passwordRecovery
  /// 이벤트 받아서 /reset-password 화면으로 강제 이동.
  static Future<void> sendPasswordReset(String email) async {
    await sb.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }
}
