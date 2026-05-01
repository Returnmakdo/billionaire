// 가계부 데이터 모델 — public/js/api.js 1:1 매핑.
// JSON 키는 Postgres snake_case, Dart 필드는 lowerCamelCase.

class Tx {
  final int id;
  final String date; // YYYY-MM-DD
  final String? card;
  final String? merchant;
  final int amount;
  final String majorCategory;
  final String? subCategory;
  final String? memo;
  final bool isFixed;

  const Tx({
    required this.id,
    required this.date,
    this.card,
    this.merchant,
    required this.amount,
    required this.majorCategory,
    this.subCategory,
    this.memo,
    required this.isFixed,
  });

  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
        id: (j['id'] as num).toInt(),
        date: j['date'] as String,
        card: j['card'] as String?,
        merchant: j['merchant'] as String?,
        amount: (j['amount'] as num).toInt(),
        majorCategory: j['major_category'] as String,
        subCategory: j['sub_category'] as String?,
        memo: j['memo'] as String?,
        isFixed: ((j['is_fixed'] as num?)?.toInt() ?? 0) == 1,
      );

  String get ym => date.substring(0, 7);
  String get year => date.substring(0, 4);
}

class Major {
  final String name;
  final int sortOrder;

  const Major({
    required this.name,
    required this.sortOrder,
  });

  factory Major.fromJson(Map<String, dynamic> j) => Major(
        name: j['major'] as String,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class Category {
  final int id;
  final String major;
  final String sub;
  final int sortOrder;

  const Category({
    required this.id,
    required this.major,
    required this.sub,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: (j['id'] as num).toInt(),
        major: j['major'] as String,
        sub: j['sub'] as String,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class Budget {
  final String major;
  final int monthlyAmount;

  const Budget({required this.major, required this.monthlyAmount});

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        major: j['major'] as String,
        monthlyAmount: (j['monthly_amount'] as num?)?.toInt() ?? 0,
      );
}

class FixedExpense {
  final int id;
  final String name;
  final String major;
  final String? sub;
  final int amount;
  final String? card;
  final int dayOfMonth;
  final bool active;
  final String? memo;
  final int sortOrder;

  const FixedExpense({
    required this.id,
    required this.name,
    required this.major,
    this.sub,
    required this.amount,
    this.card,
    required this.dayOfMonth,
    required this.active,
    this.memo,
    this.sortOrder = 0,
  });

  factory FixedExpense.fromJson(Map<String, dynamic> j) => FixedExpense(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        major: j['major'] as String,
        sub: j['sub'] as String?,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        card: j['card'] as String?,
        dayOfMonth: (j['day_of_month'] as num?)?.toInt() ?? 1,
        active: ((j['active'] as num?)?.toInt() ?? 1) == 1,
        memo: j['memo'] as String?,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

// ── 대시보드 / 통계 결과 ────────────────────────────────────

class CategoryStats {
  final String major;
  final int spent;
  final int fixedSpent;
  final int variableSpent;
  final int count;
  final int budget;

  const CategoryStats({
    required this.major,
    required this.spent,
    required this.fixedSpent,
    required this.variableSpent,
    required this.count,
    required this.budget,
  });
}

class TrendPoint {
  final String ym;
  final int total;
  const TrendPoint({required this.ym, required this.total});
}

class Dashboard {
  final String month;
  final String year;
  final int thisMonthTotal;
  final int prevMonthTotal;
  final int yearTotal;
  final int fixedTotal;
  final int variableTotal;
  final int dailyAvg;
  final List<CategoryStats> categories;
  final List<TrendPoint> trend;

  const Dashboard({
    required this.month,
    required this.year,
    required this.thisMonthTotal,
    required this.prevMonthTotal,
    required this.yearTotal,
    required this.fixedTotal,
    required this.variableTotal,
    required this.dailyAvg,
    required this.categories,
    required this.trend,
  });
}

class SubCategoryStat {
  final String major;
  final String sub;
  final int count;
  final int total;
  const SubCategoryStat({
    required this.major,
    required this.sub,
    required this.count,
    required this.total,
  });
}

class Suggestions {
  final List<String> merchants;
  final List<String> cards;
  // 카테고리(major)별 자주 쓴 가맹점. 사용 빈도순.
  final Map<String, List<String>> merchantsByMajor;
  const Suggestions({
    required this.merchants,
    required this.cards,
    this.merchantsByMajor = const <String, List<String>>{},
  });
}

class CategoriesData {
  final List<String> majors;
  final Map<String, List<Category>> byMajor;
  final List<Category> flat;

  const CategoriesData({
    required this.majors,
    required this.byMajor,
    required this.flat,
  });
}

class FixedApplyEntry {
  final String name;
  final String? date;
  final int? amount;
  final String? reason;
  const FixedApplyEntry({required this.name, this.date, this.amount, this.reason});
}

class FixedApplyResult {
  final String month;
  final int insertedCount;
  final int skippedCount;
  final List<FixedApplyEntry> inserted;
  final List<FixedApplyEntry> skipped;
  const FixedApplyResult({
    required this.month,
    required this.insertedCount,
    required this.skippedCount,
    required this.inserted,
    required this.skipped,
  });
}

/// CSV import 한 행. 검증·정규화된 거래 데이터.
class ImportRow {
  const ImportRow({
    required this.date,
    required this.amount,
    required this.majorCategory,
    this.card,
    this.merchant,
    this.subCategory,
    this.memo,
    this.isFixed = false,
  });
  final String date; // YYYY-MM-DD
  final int amount;
  final String majorCategory;
  final String? card;
  final String? merchant;
  final String? subCategory;
  final String? memo;
  final bool isFixed;
}

class PendingFixed {
  final String month;
  final int total;
  final int pending;
  const PendingFixed({
    required this.month,
    required this.total,
    required this.pending,
  });
}
