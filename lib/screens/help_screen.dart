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
          icon: Icon(Icons.arrow_back, color: AppColors.text2),
          onPressed: () => goBackOr(context, '/settings'),
        ),
        title: Text(
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
                      decoration: BoxDecoration(
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
                    Expanded(
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
                    Icon(Icons.chevron_right,
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
                '이번 달 얼마 썼는지, 지난달이랑 비교해서 한눈에 보여드려요',
                '카테고리 비율 옆 항목을 누르면 그 카테고리 거래만 모아볼 수 있어요',
                '이번 달 변동비를 어디에 많이 썼는지 태그 TOP 10으로 알려줘요',
                '태그를 누르면 같은 태그 거래만 모아볼 수 있어요',
              ],
            ),
            const _GuideCard(
              icon: Icons.receipt_long_outlined,
              title: '거래내역',
              points: [
                '오른쪽 아래 + 버튼을 누르면 거래를 추가할 수 있어요',
                '월·카테고리·검색·고정/변동으로 원하는 거래만 추려서 볼 수 있어요',
                '거래를 탭하면 바로 수정할 수 있어요',
                '정기지출이 빠진 달엔 상단 배너에서 한 번에 등록해드려요',
              ],
            ),
            const _GuideCard(
              icon: Icons.savings_outlined,
              title: '예산',
              points: [
                '카테고리마다 한 달 예산을 정해두면 진행률로 보여드려요',
                '80%를 넘으면 주황, 100%를 넘으면 빨강으로 바뀌어요',
                '예산은 변동비 기준이라 고정비는 진행률에 안 잡혀요',
              ],
            ),
            const _GuideCard(
              icon: Icons.repeat,
              title: '정기지출',
              points: [
                '구독료·월세·통신비처럼 매달 똑같이 나가는 지출을 미리 등록해두세요',
                '거래내역 상단 "일괄 등록" 배너를 누르면 그 달치를 한 번에 거래로 추가해드려요',
                '정기지출 정보를 바꾸면 이번 달 거래도 같이 업데이트돼요 (지난 달은 그대로)',
              ],
            ),
            const _GuideCard(
              icon: Icons.insights_outlined,
              title: '분석',
              points: [
                '"이번 달 분석하기"를 누르면 AI가 지출 패턴을 짚어드려요',
                '요약·패턴·예산·제안 4장을 좌우로 넘기면서 볼 수 있어요',
                '결과는 저장돼서 다음에 들어오면 바로 보여드려요',
                '거래를 고치면 저장된 결과가 초기화되고, "다시 분석"을 눌러 새로 받을 수 있어요',
              ],
            ),
            const SizedBox(height: 16),
            const _GroupTitle('자주 묻는 질문'),
            const SizedBox(height: 10),
            const _GuideCard(
              icon: Icons.help_outline,
              title: '카테고리·태그를 바꾸고 싶어요',
              points: [
                '설정 → 카테고리 관리에서 자유롭게 추가하거나 이름을 바꿀 수 있어요',
                '이미 거래에 쓰고 있는 카테고리는 거래부터 정리해야 지울 수 있어요',
              ],
            ),
            const _GuideCard(
              icon: Icons.help_outline,
              title: '다른 가계부에서 데이터 옮기고 싶어요',
              points: [
                '설정 → 데이터 가져오기에서 양식 CSV를 먼저 받아보세요',
                '엑셀에서 열어 카드사 명세서를 양식에 맞게 정리해주세요',
                'UTF-8 CSV로 저장한 다음, 다시 가져오기에서 파일만 고르면 끝이에요',
                '처음 보는 카테고리·태그가 있으면 알아서 추가해드려요',
              ],
            ),
            const _GuideCard(
              icon: Icons.help_outline,
              title: 'CSV로 백업하고 싶어요',
              points: [
                '설정 → CSV 내보내기에서 모든 거래를 한 번에 받을 수 있어요',
                '엑셀이나 구글 시트에서 바로 열려요',
                '같은 양식이라 나중에 가져오기로 그대로 복원할 수 있어요',
              ],
            ),
            const _GuideCard(
              icon: Icons.help_outline,
              title: 'AI 분석은 얼마나 자주 갱신돼요?',
              points: [
                '한 번 분석하면 결과를 저장해뒀다가 다시 보여드려요',
                '그 달 거래를 추가·수정·삭제하면 저장된 결과가 초기화돼요',
                '초기화된 뒤엔 "이번 달 분석하기"나 "다시 분석"을 눌러야 새로 받아볼 수 있어요',
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
        style: TextStyle(
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
                    style: TextStyle(
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
                      decoration: BoxDecoration(
                        color: AppColors.text3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: TextStyle(
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
