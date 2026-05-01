# 가계부 프로젝트 — 인수인계 문서

토스/뱅크샐러드 톤의 가계부. Supabase(Postgres + Auth + Edge Functions)를 백엔드로 쓰는 Flutter 앱 (Android + Web). 2026-04-29에 웹 SPA(Express + vanilla JS)를 버리고 Flutter로 단일화. 같은 Supabase 백엔드를 Android와 Web 빌드가 공유. 2026-05-01에 AI 분석/온보딩/도움말/CSV 가져오기/다크모드 추가.

## 빠른 시작

```bash
cd "C:\billionaire"

# Android 에뮬레이터
"C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat" run -d emulator-5554

# 크롬 (PC에서 빠르게 보기)
"C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat" run -d chrome

# 프로덕션 웹 빌드 (Vercel 배포용)
"C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat" build web --release
```

`r`/`R` = hot reload / restart. 웹은 hot restart만 안정적, 에셋(폰트 등) 변경은 `q` → 재실행.

**프로젝트 위치는 `C:\billionaire\` (ASCII 경로)** — 한글 폴더에서는 Gradle/aapt가 깨짐.

## 기술 스택

- **백엔드**: Supabase (Postgres + RLS + Auth + Edge Functions)
- **프론트**: Flutter 3.11+ (Material 3, GoRouter, supabase_flutter, intl, fl_chart)
- **AI**: Anthropic Claude Opus 4.7 — Edge Function 프록시 통해 호출 (API 키 클라이언트 노출 X)
- **인증**: Supabase Auth (이메일·비번, Google OAuth)
- **폰트**: Pretendard 4종 번들
- **타깃**: Android, Web. iOS/Windows desktop은 환경 셋업 필요.

### 주요 의존성
```yaml
supabase_flutter, go_router, intl
fl_chart, flutter_svg
flutter_markdown, markdown          # AI 인사이트 렌더링
file_picker                         # CSV 업로드
share_plus, path_provider           # 모바일 native 파일 공유
shared_preferences                  # 테마 로컬 캐시
```

## Supabase 정보

메모리 `supabase_setup.md`에 풀 정보. 핵심:
- Project ref: `nwndjqgipjlxxoxptusn` (region: ap-northeast-2)
- Anon key는 `lib/supabase.dart`에 박혀 있음 (RLS로 보호)
- Edge Function 시크릿: `ANTHROPIC_API_KEY` (Supabase 대시보드 Edge Functions Secrets)
- 어드민 작업은 Supabase MCP로 (`apply_migration`, `execute_sql`, `deploy_edge_function`)

## 폴더 구조

```
C:\billionaire\
├── CLAUDE.md
├── .github/workflows/deploy.yml
├── vercel.json                     # SPA fallback rewrite
├── supabase/
│   ├── schema.sql                  # 참고용
│   └── functions/spending-insights/index.ts  # AI 분석 Edge Function (Deno)
├── assets/
│   ├── fonts/                      # Pretendard 4종
│   ├── icons/                      # Google G logo
│   └── onboarding/                 # 01~04.png 슬라이드 스크린샷
└── lib/
    ├── main.dart                   # GoRouter + Auth gate + ThemeMode
    ├── theme.dart                  # AppColors (dynamic getter) + AppColorsDark + buildLight/DarkTheme
    ├── supabase.dart
    ├── auth.dart                   # AuthService (signIn/themeMode/userVersion 등)
    ├── api/
    │   ├── models.dart
    │   └── api.dart                # Api.instance + _txCache + version notifiers
    ├── state/selected_month.dart   # 전역 SelectedMonth ValueNotifier (탭 간 공유)
    ├── utils/
    │   ├── csv_download_{stub,web}.dart    # 파일 download + Web Share API
    │   ├── browser_back_{stub,web}.dart    # web: history.back()
    │   ├── is_mobile_{stub,web}.dart       # 모바일 web/native 판별
    │   └── nav_back.dart                   # goBackOr(context, fallback)
    ├── widgets/
    │   ├── common.dart             # PageHeader/AppCard/EmptyCard/ProgressTrack/_LogoutButton 등
    │   ├── format.dart             # won/smartWon/ymLabel
    │   ├── category_color.dart     # 8색 CatColor (bg/fg) 팔레트
    │   ├── kpi_card.dart, budget_card.dart, merchant_item.dart, tx_row.dart
    │   ├── amount_field.dart       # 콤마 포맷팅 입력
    │   ├── ko_date_picker.dart     # 한국어 월/연 picker
    │   ├── skeleton.dart           # 로딩 스켈레톤
    │   ├── charts.dart             # CategoryShare, MonthlyTrendBar
    │   ├── ai_insight_card.dart    # AI 인사이트 PageView 카드
    │   └── spending_insight_pages.dart  # Summary/Pattern/Budget/Suggestion 페이지 + parseInsight
    └── screens/
        ├── login_screen.dart, reset_password_screen.dart
        ├── onboarding_screen.dart  # 첫 로그인 4장 슬라이드
        ├── shell_screen.dart       # 5탭 네비
        ├── dashboard_screen.dart, transactions_screen.dart, tx_modal.dart
        ├── budgets_screen.dart, fixed_expenses_screen.dart
        ├── spending_insights_screen.dart  # AI 분석 탭
        ├── settings_screen.dart    # 메뉴 리스트 (계정/카테고리/import/export/테마/도움말)
        ├── account_settings_screen.dart, categories_screen.dart
        ├── theme_settings_screen.dart, help_screen.dart, import_screen.dart
```

## 데이터 모델 (Postgres / RLS `auth.uid() = user_id`)

- `transactions` — id, user_id, date(YYYY-MM-DD), card, merchant, amount, major_category, sub_category, memo, is_fixed (0/1), created_at, updated_at
- `majors` — PK (user_id, major), sort_order
- `categories` — id, user_id, major, sub, sort_order. UNIQUE (user_id, major, sub)
- `budgets` — PK (user_id, major), monthly_amount
- `fixed_expenses` — id, user_id, name, major, sub, amount, card, day_of_month, active, memo, sort_order
- `ai_insights` — PK (user_id, month), content (text), generated_at. AI 분석 결과 캐시. **거래 변경 시 트리거(`tx_invalidate_ai_insights`)가 해당 월 캐시 자동 삭제**.

### 트리거/RPC
- `seed_default_data_for_new_user` — auth.users INSERT 시 '기타' major + budget 시드
- `tx_invalidate_ai_insights` — transactions INSERT/UPDATE/DELETE 시 ai_insights 자동 무효화 (date 기준 month)
- `check_email_exists(p_email)` RPC — 회원가입 실시간 중복 체크
- `delete_my_account()` RPC — 본인 계정 삭제 + ON DELETE CASCADE로 모든 데이터 정리

## API 레이어 (`lib/api/api.dart`)

`Api.instance` 싱글톤. 내부 `_txCache`로 transactions 캐싱.

- 거래/카테고리/태그/예산/정기지출 CRUD (기존)
- `getDashboard(month)`, `getSubCategoryStats`, `getSuggestions` — 클라이언트 계산
- `getCachedSpendingInsight(month)` — ai_insights 직접 조회 (Edge Function 안 거침, 빠른 표시용)
- `getSpendingInsight(month, force: bool)` — Edge Function 호출 → AI 분석. force=true면 캐시 우회
- `importTransactions(rows)` — CSV import. 새 카테고리/태그 자동 등록 + 거래 batch INSERT
- `exportTransactionsCsv()` — round-trip 가능한 CSV (import 양식과 동일)

### Notifier (mutation 알림)
`txVersion`, `majorsVersion`, `categoriesVersion`, `budgetsVersion`, `fixedVersion` — 변경 시 bump. 화면이 listening해서 자동 reload.

## Edge Function: `spending-insights`

`supabase/functions/spending-insights/index.ts` (Deno + Anthropic SDK).

- 클라이언트 JWT로 사용자 거래/예산 fetch
- 집계 (카테고리/태그/가맹점/요일/이상치/예산진행)
- Claude Opus 4.7 (`thinking: adaptive`, system prompt cache_control ephemeral) 호출
- ai_insights 테이블에 결과 upsert (user_id는 DEFAULT auth.uid()로 자동)
- force=false면 캐시 hit 시 즉시 반환

**시스템 프롬프트 변경 시 `mcp__supabase__deploy_edge_function`로 재배포.** 인라인 코드 대신 파일 통째로 보내는 게 안전.

## 화면 구성 (5탭 + 사이드 라우트)

### 메인 탭 (StatefulShellRoute)
1. **대시보드** `/dashboard` — KPI 4장, 카테고리 비율, 태그 TOP 10, 6개월 추이
2. **거래내역** `/transactions` — 월/카테고리/검색/금액범위/정렬 필터, FAB 추가, 거래 모달에서 카테고리·태그 인라인 추가, 정기지출 미등록 배너 (이번 달만 표시)
3. **예산** `/budgets` — 카테고리별 변동비 진행률 + 입력 + 저장
4. **정기지출** `/fixed` — 카탈로그 CRUD. 수정 시 이번 달 매칭 거래도 동기화 (과거 달은 보존)
5. **분석** `/insights` — AI 인사이트 + 4페이지 PageView (요약/패턴/예산/제안) + 데이터 시각화

### 설정 sub 라우트 (`/settings/...`)
- `/settings` — 메뉴 리스트
- `/settings/account` — 이름/비밀번호/회원탈퇴
- `/settings/categories` — 카테고리·태그 CRUD
- `/settings/import` — CSV 일괄 등록 (템플릿 다운로드 + 파일 선택 + 미리보기)
- `/settings/theme` — 시스템/라이트/다크
- `/settings/help` — 온보딩 다시 보기 + 화면별 가이드
- `/onboarding` — 첫 로그인 자동 진입. `?from=help`면 도움말에서 닫기

## 라우팅 패턴 (중요)

- **모든 navigation은 `context.go`로 통일.** GoRouter 14.x의 `context.push`는 ImperativeRouteMatch라 URL bar 갱신 안 되는 케이스가 있음.
- **뒤로가기는 `goBackOr(context, fallback)` 헬퍼** 사용 — web에선 `window.history.back()`, mobile native에선 `Navigator.canPop` 시도 후 fallback path.
- **MaterialApp에 `key: ValueKey(brightness)`** — AppColors의 static getter는 InheritedWidget 의존이 없어 Theme 변경 시 자동 rebuild 안 됨. key 교체로 전체 재mount.

## 디자인 시스템 (다크모드)

`lib/theme.dart`에 light/dark 두 세트 + `AppColors`는 동적 getter (현재 brightness에 맞춰 light/dark 색 반환).

```dart
AppColors.bg / surface / surface2  // dynamic — light/dark 자동
AppColors.text / text2 / text3 / text4
AppColors.line / line2
AppColors.primary / primaryWeak / primaryStrong
AppColors.success / danger / warning
AppRadius.sm:10 md:14 lg:18 xl:22
```

### 다크모드 구현 (Phase 2 완료)
- `AppColors`는 `static get` (const 아님). `_isDark` static 변수에 따라 light/dark 색 반환.
- `AuthService.themeMode` — `ValueNotifier<ThemeMode>` (system/light/dark)
- 저장: 서버(user_metadata.theme_mode) + 로컬(SharedPreferences). **서버 우선**, 로그아웃 상태에선 로컬 fallback.
- main에서 `bootstrapTheme()` await로 콜드 부트 시 즉시 복원.
- `AppColors.update(brightness)`는 main의 ValueListenableBuilder에서만 호출. theme.dart의 `_build()` 안에서는 호출 X (light/dark 둘 다 build되어 마지막 호출이 덮어씀).
- ⚠️ **`const TextStyle(color: AppColors.text)` 금지** — AppColors가 const 아니라 `invalid_constant` 에러. 화면 코드에서 const 표현식 안에 AppColors.* 사용 시 const 제거 필요.

## 사용자 선호 (협업 스타일)

- 한국어로 대화. 답변은 짧게, 핵심만.
- 옵션 두세 개 + 트레이드오프 + 추천 형태로 제시. "ㄱㄱ" / "ㅇㅇ" / 알파벳으로 빠르게 결정.
- 변경 즉시 적용 → 폰/웹에서 보면서 조정하는 반복 사이클.
- 디자인 디테일에 민감 (정렬·간격·폰트·여백). UI 변경 시 모바일 레이아웃 꼭 확인.
- 솔직한 피드백 환영. **"야매 쓰지말고 근본적으로 해결" 선호** — hack/임시방편 싫어함, 진짜 원인 찾아 고치는 거 선호.
- **커밋/푸시는 절대 자동 X.** 사용자가 명시적으로 "푸시" 또는 "커밋푸시"라고 한 경우에만 git 명령. 메모 `feedback_no_auto_push.md` 참고.

## Flutter 코딩 함정

- **`setState(() => _future = someFuture)` 금지** — 화살표 람다가 Future 반환하면 런타임 throw. 항상 블록: `setState(() { _future = ...; });`
- **Stack + FractionallySizedBox 비례 막대 width collapse** — 진행률 바는 `LayoutBuilder`로 maxWidth 받아 명시 width.
- **`.order()` ascending 명시 필수** — supabase_flutter 일부 버전에서 ascending 미명시 시 desc로 동작. `listMajors`/`listBudgets`/`listCategories` 등 항상 `ascending: true` 명시.
- **`const TextStyle(color: AppColors.text)` 금지** (다크모드 반영) — AppColors가 dynamic getter라 const 표현식 안에서 invalid_constant.
- **GoRouter `context.push` URL 갱신 누락** — 모든 navigation을 `context.go`로 + `goBackOr` 헬퍼.
- **모달/popup 안에서 displayName 같은 캐시된 값** — `AuthService.userVersion` ValueListenableBuilder로 감싸야 즉시 반영.
- **마크다운 한글 옆 `**`/`~`** — flutter_markdown이 한글 옆 단어 경계 인식 못 해서 `**xxx**` 그대로 노출되거나 `8~9건`/`6~7건`처럼 단일 ~가 strikethrough로 매칭됨. `_normalizeBold()` 헬퍼로 클라이언트 보정.
- **FAB hero tag 충돌** — StatefulShellRoute로 여러 탭 keep alive 시 FAB의 기본 hero tag 같으면 에러. 각 FAB에 `heroTag: 'fab_xxx'` 명시.

## 빌드/실행 디테일

- Flutter SDK: `C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat`
- Android emulator: `flutter emulators --launch billionaire`
- 첫 빌드 ~60초, 이후 hot reload 가능. 웹은 hot restart만 안정.
- **OAuth redirect URL** — 끝에 `/` 명시. `Uri.base.origin` 만으로 보내면 Supabase 화이트리스트 `/**`와 매치 안 되어 Site URL로 fallback.
- **로컬 OAuth 테스트** — `--web-port 8080`으로 포트 고정 + Supabase Redirect URLs에 `http://localhost:8080/**` 등록.

## 다음 단계 후보

- **알림** (예산 임박 / 정기지출) — 작업 작음, 임팩트 큼
- **APK 빌드 + 안드 SMS 파싱** — 토스/뱅샐 못 하는 영역. 결제 SMS 자동 파싱 → 거래 자동 추가
- **iOS** — Mac 빌드 환경 필요
- **오프라인 캐시** — `drift`로 로컬 캐시 + 백그라운드 sync
- **AI CSV 자동 분류** — 카드사 CSV의 가맹점들을 Claude한테 넘겨 카테고리 자동 분류 (현재는 우리 양식만 import)

## 작업 시 주의

- **DB 스키마 변경**은 Supabase MCP의 `apply_migration`으로. `supabase/schema.sql`은 참고용.
- **Edge Function 변경**은 `supabase/functions/spending-insights/index.ts` 편집 후 `mcp__supabase__deploy_edge_function`으로 통째로 재배포.
- **anon key 노출 OK** — RLS가 보호. service_role 키는 절대 클라이언트에 두지 말 것.
- **사용자 추가/삭제**는 Supabase 대시보드 → Authentication → Users.
- **화면 변경 후 `flutter analyze` 0 issues 유지**.
- **CSV 양식**은 export/import 동일: `날짜,금액,카테고리,가맹점,카드/결제수단,태그,메모,고정비` (필수 3개 앞쪽).
- **테스트 데이터 입력**은 Supabase MCP `execute_sql`로 직접 INSERT (한글 cp949 문제 회피).

---

다음 세션 진입점: 이 문서 위에서 "현재 상태" 확인 후 작업.
