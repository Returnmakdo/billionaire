import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';

class AuthService {
  static User? get currentUser => sb.auth.currentUser;
  static String? get currentUserId => sb.auth.currentUser?.id;
  static Stream<AuthState> get onAuthStateChange => sb.auth.onAuthStateChange;

  static Future<void> signIn(String email, String password) async {
    await sb.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await sb.auth.signOut();
  }
}
