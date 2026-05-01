import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../utils/nav_back.dart';
import '../widgets/common.dart';

/// 설정 → 도움말. 화면별 사용법 카드 + 온보딩 다시 보기.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text2),
          onPressed: () => goBackOr(context, '/settings'),
        ),
        title: const Text(
          '도움말',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // 온보딩 다시 보기 — primaryWeak hero 카드.
            InkWell(
              onTap: () => context.go('/onboarding?from=help'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryWeak,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '소개 슬라이드 다시 보기',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '핵심 기능 4가지 빠르게 훑어보기',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 22, color: AppColors.primaryStrong),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _GroupTitle('각 화면 사용법'),
            const SizedBox(height: 10),
            const _GuideCard(
              icon: Icons.dashboard_outlined,
              title: '대시보드',
              points: [
                '이번 달 KPI: 총 지출, 지난달, 일평균, 연 누적',
                '카테고리 비율 클릭 시 해당 카테고리 거래내역으로 이동',
                '태그 TOP 10에서 가장 많이 쓴 변동비 태그 확인',
              ],
            ),
            const _GuideCard(
              icon: Icons.receipt_long_outlined,
              title: '거래내역',
              points: [
                '우하단 + 버튼으로 거래 추가',
                '월/카테고리/검색/고정·변동 필터로 좁히기',
                '거래 행 탭하면 수정 모달',
                '정기지출 미등록 배너에서 한 번에 일괄 등록',
              ],
            ),
            const _GuideCard(
              icon: Icons.savings_outlined,
              title: '예산',
              points: [
                '카테고리별 변동비 월예산 입력',
                '진행률 80% 이상이면 주황, 100% 초과면 빨강',
                '진행률 바 클릭 시 해당 카테고리 거래로 이동',
              ],
            ),
            const _GuideCard(
              icon: Icons.repeat,
              title: '정기지출',
              points: [
                '구독·월세·통신비처럼 매달 같은 금액 지출 등록',
                '활성으로 두면 매달 1일에 거래로 자동 변환 가능',
                '거래내역 상단 "일괄 등록" 배너로 누적 처리',
              ],
            ),
            const _GuideCard(
              icon: Icons.insights_outlined,
              title: '분석',
              points: [
                '"이번 달 분석하기" 버튼으로 AI 인사이트 생성',
                '4페이지 스와이프: 요약 / 패턴 / 예산 / 제안',
                '거래를 추가/수정하면 캐시가 자동 무효화',
                '"다시 분석"으로 새 결과 강제 갱신',
              ],
            ),
            const SizedBox(height: 16),
            const _GroupTitle('자주 묻는 질문'),
            const SizedBox(height: 10),
            const _GuideCard(
              icon: Icons.help_outline,
              title: '카테고리·태그를 바꾸고 싶어요',
              points: [
                '설정 → 카테고리 관리에서 추가/이름 변경/삭제',
                '거래에 사용된 카테고리는 삭제 안 됨 (먼저 거래 정리)',
              ],
            ),
            const _GuideCard(
              icon: Icons.help_outline,
              title: '다른 가계부에서 데이터 옮기고 싶어요',
              points: [
                '설정 → 데이터 가져오기에서 템플릿 CSV 다운로드',
                '엑셀에서 열어 카드사 명세서 데이터를 양식대로 정리',
                'UTF-8 CSV로 저장 후 다시 가져오기 → 파일 선택',
                '새 카테고리/태그가 있으면 자동으로 추가됨',
              ],
            ),
            const _GuideCard(
              icon: Icons.help_outline,
              title: 'CSV로 백업하고 싶어요',
              points: [
                '설정 → CSV 내보내기에서 모든 거래 다운로드',
                '엑셀/구글 시트에서 바로 열림',
                '같은 양식이라 데이터 가져오기로 다시 import 가능',
              ],
            ),
            const _GuideCard(
              icon: Icons.help_outline,
              title: 'AI 분석은 얼마나 자주 갱신돼요?',
              points: [
                '한 번 생성하면 그 달의 분석은 캐시',
                '거래를 추가/수정/삭제하면 해당 월 캐시 자동 만료',
                '같은 결과 다시 보기 = 캐시 / 새로 = "다시 분석"',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.text2,
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.points,
  });
  final IconData icon;
  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryWeak,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final p in points) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppColors.text3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
