# 가계부 프로젝트 — 인수인계 문서

토스/뱅크샐러드 톤의 가계부. Supabase(Postgres + Auth)를 백엔드로 쓰는 Flutter 앱 (Android + Web). 2026-04-29에 웹 SPA(Express + vanilla JS)를 버리고 Flutter로 단일화. 같은 Supabase 백엔드를 Android와 Web 빌드가 공유.

## 빠른 시작

```bash
cd "C:\billionaire\billionaire"

# Android 에뮬레이터
"C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat" run -d emulator-5554

# 크롬 (PC에서 빠르게 보기)
"C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat" run -d chrome

# 프로덕션 웹 빌드 (Vercel 배포용)
"C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat" build web --release
# → billionaire/build/web/ 에 정적 파일 생성
```

`r`/`R` = hot reload / restart. 웹은 hot restart만 안정적, 에셋(폰트 등) 변경은 `q` → 재실행.

**프로젝트 위치는 `C:\billionaire\` (ASCII 경로)** — 한글 폴더(`C:\Users\치영\…`)에서는 Gradle/aapt가 깨져서 2026-04-27에 옮김.

## 기술 스택

- **백엔드**: Supabase (Postgres + RLS + Auth + REST/realtime)
- **프론트**: Flutter 3.11+ (Material 3, GoRouter, supabase_flutter, intl)
- **인증**: Supabase Auth (이메일·비번)
- **폰트**: Pretendard (`assets/fonts/Pretendard-{Regular,Medium,SemiBold,Bold}.otf` 번들)
- **타깃**: Android, Web. iOS/Windows desktop은 환경 셋업 필요.

## Supabase 정보

메모리 `supabase_setup.md`에 풀 정보. 핵심:
- Project ref: `nwndjqgipjlxxoxptusn` (region: ap-northeast-2 / Seoul)
- URL: `https://nwndjqgipjlxxoxptusn.supabase.co`
- Anon key는 `billionaire/lib/supabase.dart`에 박혀 있음 (RLS로 보호되니 클라이언트 노출 OK)
- 어드민 작업은 Supabase MCP로 (`apply_migration`, `execute_sql`, `list_tables` 등)
- 사용자 추가/삭제는 MCP에 없음 → Supabase 대시보드에서 직접

## 폴더 구조

```
C:\billionaire\
├── CLAUDE.md
├── supabase/schema.sql       # 참고용 스키마 (실제 변경은 MCP 마이그레이션)
├── 가계부.xlsx               # 사용자 원본 데이터 백업
└── billionaire/              # Flutter 프로젝트
    ├── pubspec.yaml          # supabase_flutter, go_router, intl + Pretendard 번들
    ├── android/, web/
    ├── assets/fonts/         # Pretendard otf 4종
    └── lib/
        ├── main.dart              # GoRouter + Auth gate (refreshListenable)
        ├── theme.dart             # ThemeData + AppColors/AppRadius
        ├── supabase.dart          # initSupabase() + sb getter (anon key)
        ├── auth.dart              # AuthService (signIn/signOut/currentUser)
        ├── api/
        │   ├── models.dart        # Tx, Major, Category, Budget, FixedExpense, Dashboard, etc.
        │   └── api.dart           # Api.instance — Supabase 호출 + _txCache
        ├── widgets/
        │   ├── format.dart        # won/smartWon/wonShort/ymLabel/fmtDate
        │   ├── category_color.dart # 8색 팔레트 + CategoryDot
        │   ├── common.dart        # PageHeader/MonthSwitcher/AppCard/ProgressTrack/etc.
        │   ├── kpi_card.dart
        │   ├── budget_card.dart
        │   ├── merchant_item.dart
        │   ├── tx_row.dart
        │   └── amount_field.dart
        └── screens/
            ├── login_screen.dart
            ├── shell_screen.dart            # 하단 탭 네비 (5탭 통일)
            ├── dashboard_screen.dart
            ├── transactions_screen.dart
            ├── tx_modal.dart                # 거래 추가/수정
            ├── budgets_screen.dart
            ├── fixed_expenses_screen.dart
            └── categories_screen.dart
```

## 데이터 모델 (Supabase / Postgres)

모든 테이블에 `user_id uuid` 칼럼 + RLS 정책 `auth.uid() = user_id` (자기 데이터만 읽고 쓰기 가능).

### `transactions` — 거래 내역
```sql
id (bigserial PK), user_id (FK auth.users),
date (text YYYY-MM-DD), card, merchant,
amount (bigint), major_category, sub_category, memo,
is_fixed (int 0/1),
created_at, updated_at (트리거로 자동)
```

### `majors` — 카테고리
```sql
PK (user_id, major), sort_order
```

### `categories` — 태그
```sql
id (bigserial PK), user_id, major, sub, sort_order
UNIQUE (user_id, major, sub)
```

### `budgets` — 카테고리별 월예산
```sql
PK (user_id, major), monthly_amount, updated_at
```

### `fixed_expenses` — 정기지출 카탈로그
```sql
id, user_id, name, major, sub, amount, card, day_of_month,
active (0/1), memo, sort_order, created_at, updated_at
```

거래 INSERT 시 같은 월/이름/카테고리 조합이면 클라이언트가 중복 방지(skip).

## API 레이어 (`billionaire/lib/api/api.dart`)

`Api.instance` 싱글톤. 내부에서 supabase-js 직접 호출하고 `_txCache`로 transactions를 캐싱.

- 거래 CRUD: `listTransactions`, `createTransaction`, `updateTransaction`, `deleteTransaction`
- 카테고리: `listMajors`, `createMajor`, `renameMajor`, `deleteMajor`
- 태그: `listCategories`, `createCategory`, `renameCategory`, `deleteCategory`
- 예산: `listBudgets`, `saveBudgets`
- 대시보드: `getDashboard(month)` — **클라이언트에서 계산**. 한 번 fetch한 transactions 캐시에서 합산.
- 통계: `getSuggestions`, `getSubCategoryStats` — 같은 캐시에서 계산
- 정기지출: `listFixedExpenses`, `createFixedExpense`, `updateFixedExpense`, `deleteFixedExpense`, `applyFixedExpenses`, `getPendingFixedExpenses`

캐시는 mutating ops 후에 `invalidateTx()`로 자동 무효화. 사용자 데이터가 수천 건 단위로 늘면 dashboard용 RPC를 만들거나 month 범위로 좁혀 fetch하는 식으로 최적화 필요.

## 화면 구성 (5개 탭, 모바일/웹 동일 하단 탭바)

1. **대시보드** — KPI 4장(이번달/지난달/일평균/연 누적, 1천만+는 `smartWon`으로 자동 단축), 변동비 예산 진행률, 태그 TOP 10, 6개월 추이 막대
2. **거래내역** — 월/카테고리/세부/검색/고정·변동 필터, FAB로 추가, 행 클릭으로 수정. 정기지출 미등록 시 일괄 등록 배너
3. **예산** — 카테고리별 변동비 진행률 + 입력
4. **정기지출** — 카탈로그 CRUD, 활성/비활성 토글
5. **카테고리** — 카테고리·태그 CRUD

`PageHeader` 우측에 사람 아이콘 popup → 로그아웃 (모든 탭 공통).

## 디자인 시스템

`lib/theme.dart`의 `AppColors` / `AppRadius`가 진실. 톤은 토스 블루 + 무채색.

```dart
AppColors.bg / surface / surface2
AppColors.text / text2 / text3 / text4
AppColors.line (#E5E8EB) / line2 (#F0F2F5)
AppColors.primary (#3182F6) / primaryWeak / primaryStrong
AppColors.success / danger / warning
AppRadius.sm:10 md:14 lg:18 xl:22
```

**원칙:**
- 흰 배경 + 옅은 그림자 (border 거의 없음)
- 묵직한 큰 숫자 (700 weight + `FontFeature.tabularFigures()`)
- 카드 패딩 14~22, 둥근 모서리 14~22
- 카테고리 식별은 8가지 색 dot (`widgets/category_color.dart#categoryColor`)
- ≥16px 입력 폰트(iOS zoom 방지), `MediaQuery.sizeOf(context).width >= 700`로 데스크톱 분기

## 사용자 선호 (협업 스타일)

- 한국어로 대화. 답변은 짧게, 핵심만.
- 옵션 두세 개 + 트레이드오프 + 추천 형태로 제시받는 걸 선호. "ㄱㄱ" / "ㅇㅇ" / 알파벳으로 빠르게 결정.
- 변경은 즉시 적용 → 폰/웹에서 보면서 조정하는 반복 사이클.
- 디자인 디테일에 민감 (정렬·간격·폰트·여백). UI 변경 시 모바일 레이아웃 꼭 확인.
- 솔직한 피드백 환영. "이거 쓸만해?" 같은 메타 질문이 종종 들어옴.

## Flutter 코딩 함정 (실제로 당함)

- **`setState(() => _future = someFuture)` 절대 금지.** 화살표 람다는 할당된 값을 반환하는데, Future를 반환하면 Flutter가 런타임에 `setState() callback argument returned a Future`로 throw. **`flutter analyze`는 못 잡음.** Future나 async 결과를 setState 안에서 할당하려면 항상 블록 syntax: `setState(() { _future = ...; });`
- 비-Future 필드(`_busy = true`)는 화살표 OK이지만 Future 쪽은 일관되게 블록 쓰는 게 안전.
- **Stack + FractionallySizedBox 비례 막대는 width collapse**. `Container(decoration: bg) > FractionallySizedBox` 또는 `Stack(Positioned.fill(bg) + FractionallySizedBox)`은 부모 제약이 모호하면 배경이 0 width가 됨. 진행률 바는 `LayoutBuilder`로 maxWidth 받아서 두 Container 모두 명시 width(`width: w`, `width: w * p`)로 그리는 게 안전. (`widgets/common.dart#ProgressTrack` 참고)

## 빌드/실행 디테일

- Flutter SDK: `C:\Users\Public\flutter-sdk\flutter\bin\flutter.bat`
- JDK: Android Studio JBR (`flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"`로 박혀있음)
- Android emulator: `flutter emulators --launch billionaire`
- 첫 빌드 ~60초, 이후 hot reload (`r`/`R`) 가능
- 웹은 hot restart(`R`)만 안정적. 에셋 변경(폰트 등)은 `q` 후 재실행.

## 한글 경로 회고

- 옛 위치(`C:\Users\치영\Desktop\billionare\`)는 Gradle이 ASCII 경로 강제 + aapt가 cp949로 한글 못 읽어서 fail
- 현재 `C:\billionaire\`로 옮긴 후 `android.overridePathCheck=true` 빼고도 정상 동작
- 다른 Windows 머신에서 셋업하면 처음부터 ASCII 경로에 두기

## 알려진 이슈

- **사용자 데이터에 "차량정비 (기타)"** — 분류 마스터엔 차량정비가 교통에 있는데 거래는 기타로 들어감. 거래 클릭해서 카테고리 교통으로 변경하면 정리됨.
- **Supabase 1000행 페이지 제한** — `api.dart#_getAllTx`는 1000건씩 페이지네이션. 지금 데이터 200여 건이라 1페이지로 끝.
- **세션 만료** — Supabase 세션은 1시간. 자동 갱신 켜뒀지만, 오랜만에 열면 한 번 로그인 다시 해야 할 수 있음.
- **차트 색상 불일치 가능성** — `category_color.dart`가 8개 고정 분류 외엔 hash로 결정. 새 카테고리 추가하면 색이 일관되지 않을 수 있음.
- **옛 폴더 잔재** — `C:\Users\치영\Desktop\billionare\` 빈 껍데기 폴더가 잠겨서 못 지움. 재부팅 후 수동 삭제.

## 다음 단계 후보

- **Vercel 웹 배포** — `flutter build web --release` → `billionaire/build/web/`을 `vercel deploy --prod` 로 푸시. base href는 `/` 그대로.
- **iOS** — Mac 빌드 환경 필요
- **Windows desktop** — Visual Studio C++ workload 필요
- **오프라인 캐시** — 인터넷 없으면 동작 X. 필요시 `drift`로 로컬 캐시 + 백그라운드 sync
- **푸시 알림** — 매월 1일 정기지출 자동 등록 알림 등
- **반복 거래 자동 등록 (server-side)** — Supabase Edge Function + 크론

## 작업 시 주의

- **DB 스키마 변경**은 Supabase MCP의 `apply_migration`으로. `supabase/schema.sql`은 참고용 — 실제 변경은 마이그레이션 단위로.
- **anon key 노출 OK** — RLS가 보호. service_role 키는 절대 클라이언트에 두지 말 것.
- **사용자 추가/삭제**는 Supabase 대시보드 → Authentication → Users에서 직접. 새 사용자는 빈 데이터로 시작.
- **`setState(() => _future = ...)` 패턴 금지** — 위 "Flutter 코딩 함정" 참고.
- **화면 변경 후 `flutter analyze` 0 issues 유지**.
- **거래 모달(`tx_modal.dart`)과 정기지출 모달(`fixed_expenses_screen.dart` 안)** 분리됨. 자동완성은 `Autocomplete<String>` 위젯. 콤마는 `widgets/amount_field.dart`의 `_ThousandsFormatter`.
- **테스트 데이터 입력**은 폰/웹에서 직접 (Bash로 curl은 한글 cp949로 깨짐).

---

다음 세션 진입점: 이 문서 위에서 "현재 상태" 확인 후 작업.
