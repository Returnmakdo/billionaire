import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth.dart';
import '../theme.dart';
import '../utils/nav_back.dart';

/// 첫 로그인 시 4장 PageView로 핵심 기능 소개. 한 번 본 후
/// user_metadata.onboarding_seen=true 저장 → 다음부터 표시 안 됨.
/// 설정 → 도움말에서 다시 볼 수 있음.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.fromHelp = false});

  /// 도움말에서 진입했으면 "건너뛰기" 대신 "닫기" + 완료 시 metadata 안 건드림.
  final bool fromHelp;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _slides = <_Slide>[
    _Slide(
      image: 'assets/onboarding/01.png',
      title: '기록은 단순하게',
      body: '거래를 추가하면 카테고리·태그·고정/변동까지 한 번에 정리해드려요.',
    ),
    _Slide(
      image: 'assets/onboarding/02.png',
      title: '한 달이 한 화면에',
      body: 'AI가 거래를 보고 패턴, 이상치, 다음 달 제안까지 짚어줘요.',
    ),
    _Slide(
      image: 'assets/onboarding/03.png',
      title: '예산은 한 번 세우고',
      body: '카테고리별 진행률이 매일 자동으로 업데이트돼요.',
    ),
    _Slide(
      image: 'assets/onboarding/04.png',
      title: '매달 같은 지출은 자동',
      body: '구독·월세·통신비, 한 번 등록하면 매달 자동 반영해요.',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!widget.fromHelp) {
      try {
        await AuthService.markOnboardingSeen();
      } catch (_) {}
    }
    if (!mounted) return;
    if (widget.fromHelp) {
      // 도움말에서 진입한 경우: history.back()으로 onboarding entry 정리.
      // (go로 이동하면 history에 새 entry 쌓여 도움말 뒤로가기가 다시 onboarding으로 감)
      goBackOr(context, '/settings/help');
    } else {
      context.go('/dashboard');
    }
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 — 건너뛰기/닫기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text3,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(widget.fromHelp ? '닫기' : '건너뛰기'),
                  ),
                ],
              ),
            ),
            // PageView
            Expanded(
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),
            ),
            // 하단 — dot indicator + 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DotIndicator(count: _slides.length, current: _page),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      textStyle: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(isLast ? '시작하기' : '다음'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.image,
    required this.title,
    required this.body,
  });
  final String image;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 실제 화면 스크린샷 — 부드러운 라운드 + 옅은 그림자로 카드 느낌.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  slide.image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              height: 1.3,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13.5,
              color: AppColors.text2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});
  final int count;
  final int current;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == current ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ],
    );
  }
}
