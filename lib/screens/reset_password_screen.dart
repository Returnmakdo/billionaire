import 'package:flutter/material.dart';

import '../auth.dart';
import '../theme.dart';
import '../widgets/common.dart' show errorMessage;

/// 비밀번호 재설정 메일 링크로 들어왔을 때 보여주는 화면.
/// 새 비밀번호 입력 → 변경 → 로그아웃 → 로그인 화면.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _busy = false;

  bool _hasMinLength = false;
  bool _hasLower = false;
  bool _hasUpper = false;
  bool _hasDigit = false;
  bool _hasSymbol = false;

  bool get _passwordValid =>
      _hasMinLength && _hasLower && _hasUpper && _hasDigit && _hasSymbol;
  bool get _passwordsMatch =>
      _passConfirmCtrl.text.isNotEmpty &&
      _passCtrl.text == _passConfirmCtrl.text;

  @override
  void dispose() {
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String v) {
    setState(() {
      _hasMinLength = v.length >= 8;
      _hasLower = RegExp(r'[a-z]').hasMatch(v);
      _hasUpper = RegExp(r'[A-Z]').hasMatch(v);
      _hasDigit = RegExp(r'\d').hasMatch(v);
      _hasSymbol = RegExp(r'[^a-zA-Z0-9\s]').hasMatch(v);
    });
  }

  Future<void> _submit() async {
    if (!_passwordValid) {
      _showError('비밀번호 조건을 모두 만족해야 해요');
      return;
    }
    if (!_passwordsMatch) {
      _showError('비밀번호가 일치하지 않아요');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.updatePassword(_passCtrl.text);
      AuthService.recoveryMode.value = false;
      // 로그아웃해서 새 비번으로 직접 로그인하게 유도
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('비밀번호를 변경했어요. 새 비밀번호로 로그인해주세요'),
          backgroundColor: AppColors.text,
          duration: Duration(seconds: 4),
        ));
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessage(e));
      setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    AuthService.recoveryMode.value = false;
    await AuthService.signOut();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '새 비밀번호 설정',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '비밀번호를 새로 설정해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5, color: AppColors.text3),
                    ),
                    const SizedBox(height: 24),
                    const _Label('새 비밀번호'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      onChanged: _onPasswordChanged,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ReqChip(label: '8자 이상', met: _hasMinLength),
                        _ReqChip(label: '대문자', met: _hasUpper),
                        _ReqChip(label: '소문자', met: _hasLower),
                        _ReqChip(label: '숫자', met: _hasDigit),
                        _ReqChip(label: '특수문자', met: _hasSymbol),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _Label('새 비밀번호 확인'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passConfirmCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        errorText: _passConfirmCtrl.text.isNotEmpty &&
                                !_passwordsMatch
                            ? '비밀번호가 일치하지 않아요'
                            : null,
                        suffixIcon: _passConfirmCtrl.text.isEmpty
                            ? null
                            : (_passwordsMatch
                                ? Icon(Icons.check_circle_outline,
                                    color: AppColors.success, size: 20)
                                : Icon(Icons.error_outline,
                                    color: AppColors.danger, size: 20)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? '변경 중...' : '비밀번호 변경'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _cancel,
                      child: Text(
                        '취소하고 로그인 화면으로',
                        style: TextStyle(
                            color: AppColors.text3, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 13,
          color: AppColors.text2,
          fontWeight: FontWeight.w500),
    );
  }
}

class _ReqChip extends StatelessWidget {
  const _ReqChip({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met ? AppColors.primaryWeak : AppColors.surface2,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: met ? AppColors.primary : AppColors.text4,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: met ? AppColors.primaryStrong : AppColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
