import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth.dart';
import '../supabase.dart';
import 'models.dart';

/// Supabase에 직접 통신하는 Repository.
/// public/js/api.js와 시그니처를 맞춰서 화면 코드가 1:1 매핑되도록 한다.
class Api {
  Api._() {
    _lastUserId = sb.auth.currentUser?.id;
    sb.auth.onAuthStateChange.listen((state) {
      final newId = state.session?.user.id;
      if (newId != _lastUserId) {
        _lastUserId = newId;
        invalidateAllCaches();
      }
    });
  }
  static final Api instance = Api._();

  String? _lastUserId;

  // ── transactions 캐시 ───────────────────────────────────────
  List<Tx>? _txCache;

  /// 데이터가 변경될 때마다 증가하는 버전 노티파이어들. 다른 화면에서
  /// listen 해서 자기 데이터를 자동 reload 하도록 알림용으로 사용.
  final ValueNotifier<int> txVersion = ValueNotifier(0);
  final ValueNotifier<int> majorsVersion = ValueNotifier(0);
  final ValueNotifier<int> categoriesVersion = ValueNotifier(0);
  final ValueNotifier<int> budgetsVersion = ValueNotifier(0);
  final ValueNotifier<int> fixedVersion = ValueNotifier(0);

  void invalidateTx() {
    _txCache = null;
    txVersion.value++;
  }

  /// 모든 캐시 무효화 + 모든 버전 bump → listening 중인 화면들이 일괄 reload.
  /// 사용자 전환(로그아웃→다른 계정 로그인) 시 호출.
  void invalidateAllCaches() {
    _txCache = null;
    txVersion.value++;
    majorsVersion.value++;
    categoriesVersion.value++;
    budgetsVersion.value++;
    fixedVersion.value++;
  }

  String _uid() {
    final id = AuthService.currentUserId;
    if (id == null) throw Exception('로그인이 필요합니다.');
    return id;
  }

  Future<List<Tx>> _getAllTx() async {
    final cached = _txCache;
    if (cached != null) return cached;
    final all = <Tx>[];
    const pageSize = 1000;
    var from = 0;
    while (true) {
      final rows = await sb
          .from('transactions')
          .select('*')
          .order('date', ascending: false)
          .order('id', ascending: false)
          .range(from, from + pageSize - 1);
      final list = (rows as List)
          .map((e) => Tx.fromJson(e as Map<String, dynamic>))
          .toList();
      all.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    _txCache = all;
    return all;
  }

  // ── transactions ─────────────────────────────────────────────
  Future<List<Tx>> listTransactions({
    String? month,
    String? major,
    String? sub,
    String? q,
    bool? fixed,
  }) async {
    dynamic query = sb.from('transactions').select('*');
    if (month != null) {
      query = query.gte('date', '$month-01').lte('date', '$month-31');
    }
    if (major != null) query = query.eq('major_category', major);
    if (sub != null) query = query.eq('sub_category', sub);
    if (q != null && q.isNotEmpty) {
      query = query.or('merchant.ilike.%$q%,memo.ilike.%$q%');
    }
    if (fixed == true) query = query.eq('is_fixed', 1);
    if (fixed == false) query = query.eq('is_fixed', 0);
    final rows = await query
        .order('date', ascending: false)
        .order('id', ascending: false);
    return (rows as List)
        .map((e) => Tx.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Tx> createTransaction({
    required String date,
    String? card,
    String? merchant,
    required int amount,
    required String majorCategory,
    String? subCategory,
    String? memo,
    bool isFixed = false,
  }) async {
    final payload = {
      'user_id': _uid(),
      'date': date,
      'card': card,
      'merchant': merchant,
      'amount': amount,
      'major_category': majorCategory,
      'sub_category': subCategory,
      'memo': memo,
      'is_fixed': isFixed ? 1 : 0,
    };
    final row = await sb
        .from('transactions')
        .insert(payload)
        .select()
        .single();
    invalidateTx();
    return Tx.fromJson(row);
  }

  Future<Tx> updateTransaction(
    int id, {
    String? date,
    String? card,
    String? merchant,
    int? amount,
    String? majorCategory,
    String? subCategory,
    String? memo,
    bool? isFixed,
    // null 명시 가능 항목용 sentinel — 필요해지면 유지하되 지금은 nullable 인자로 충분.
  }) async {
    final payload = <String, dynamic>{};
    if (date != null) payload['date'] = date;
    if (card != null) payload['card'] = card;
    if (merchant != null) payload['merchant'] = merchant;
    if (amount != null) payload['amount'] = amount;
    if (majorCategory != null) payload['major_category'] = majorCategory;
    if (subCategory != null) payload['sub_category'] = subCategory;
    if (memo != null) payload['memo'] = memo;
    if (isFixed != null) payload['is_fixed'] = isFixed ? 1 : 0;
    final row = await sb
        .from('transactions')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    invalidateTx();
    return Tx.fromJson(row);
  }

  Future<void> deleteTransaction(int id) async {
    await sb.from('transactions').delete().eq('id', id);
    invalidateTx();
  }

  // ── majors ──────────────────────────────────────────────────
  Future<List<Major>> listMajors() async {
    final rows = await sb
        .from('majors')
        .select('major, sort_order')
        .order('sort_order', ascending: true)
        .order('major', ascending: true);
    return (rows as List)
        .map((e) => Major.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Major> createMajor(String name) async {
    final userId = _uid();
    final clean = name.trim();
    if (clean.isEmpty) throw Exception('카테고리 이름이 필요합니다.');
    final maxRow = await sb
        .from('majors')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    final next = ((maxRow?['sort_order'] as num?)?.toInt() ?? -1) + 1;
    try {
      await sb.from('majors').insert({
        'user_id': userId,
        'major': clean,
        'sort_order': next,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('이미 존재하는 카테고리입니다.');
      rethrow;
    }
    await sb.from('budgets').insert({
      'user_id': userId,
      'major': clean,
      'monthly_amount': 0,
    });
    majorsVersion.value++;
    budgetsVersion.value++;
    return Major(name: clean, sortOrder: next);
  }

  Future<void> renameMajor(String oldName, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) throw Exception('새 이름이 필요합니다.');
    if (clean == oldName) return;
    final dup = await sb
        .from('majors')
        .select('major')
        .eq('major', clean)
        .maybeSingle();
    if (dup != null) throw Exception('같은 이름의 카테고리가 이미 있습니다.');
    await sb.from('majors').update({'major': clean}).eq('major', oldName);
    await sb.from('categories').update({'major': clean}).eq('major', oldName);
    await sb.from('budgets').update({'major': clean}).eq('major', oldName);
    await sb
        .from('transactions')
        .update({'major_category': clean}).eq('major_category', oldName);
    await sb
        .from('fixed_expenses')
        .update({'major': clean}).eq('major', oldName);
    invalidateTx();
    majorsVersion.value++;
    categoriesVersion.value++;
    budgetsVersion.value++;
    fixedVersion.value++;
  }

  Future<void> deleteMajor(String major) async {
    final usage = await sb
        .from('transactions')
        .select('id')
        .eq('major_category', major)
        .count(CountOption.exact);
    if (usage.count > 0) {
      throw Exception('이 카테고리를 사용하는 거래가 ${usage.count}건 있어 삭제할 수 없습니다.');
    }
    await sb.from('categories').delete().eq('major', major);
    await sb.from('budgets').delete().eq('major', major);
    await sb.from('majors').delete().eq('major', major);
    majorsVersion.value++;
    categoriesVersion.value++;
    budgetsVersion.value++;
  }

  // ── categories ──────────────────────────────────────────────
  Future<CategoriesData> listCategories() async {
    final majorRows = await sb
        .from('majors')
        .select('major')
        .order('sort_order', ascending: true)
        .order('major', ascending: true);
    final majors =
        (majorRows as List).map((r) => r['major'] as String).toList();
    final rows = await sb
        .from('categories')
        .select('id, major, sub, sort_order')
        .order('major', ascending: true)
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    final flat = (rows as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    final byMajor = <String, List<Category>>{for (final m in majors) m: []};
    for (final c in flat) {
      byMajor.putIfAbsent(c.major, () => []).add(c);
    }
    return CategoriesData(majors: majors, byMajor: byMajor, flat: flat);
  }

  Future<Category> createCategory(String major, String sub) async {
    final userId = _uid();
    final m = major.trim();
    final s = sub.trim();
    if (m.isEmpty || s.isEmpty) throw Exception('major, sub 필수');
    final maxRow = await sb
        .from('categories')
        .select('sort_order')
        .eq('major', m)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    final next = ((maxRow?['sort_order'] as num?)?.toInt() ?? -1) + 1;
    try {
      final row = await sb
          .from('categories')
          .insert({
            'user_id': userId,
            'major': m,
            'sub': s,
            'sort_order': next,
          })
          .select()
          .single();
      categoriesVersion.value++;
      return Category.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('이미 존재하는 태그입니다.');
      rethrow;
    }
  }

  Future<Category> renameCategory(int id, String sub) async {
    final newSub = sub.trim();
    if (newSub.isEmpty) throw Exception('sub 필요');
    final cur = await sb.from('categories').select('*').eq('id', id).single();
    final curMajor = cur['major'] as String;
    final curSub = cur['sub'] as String;
    if (curSub == newSub) {
      return Category(id: id, major: curMajor, sub: newSub);
    }
    final dup = await sb
        .from('categories')
        .select('id')
        .eq('major', curMajor)
        .eq('sub', newSub)
        .maybeSingle();
    if (dup != null) throw Exception('같은 이름의 태그가 이미 있습니다.');
    await sb.from('categories').update({'sub': newSub}).eq('id', id);
    await sb
        .from('transactions')
        .update({'sub_category': newSub})
        .eq('major_category', curMajor)
        .eq('sub_category', curSub);
    invalidateTx();
    categoriesVersion.value++;
    return Category(id: id, major: curMajor, sub: newSub);
  }

  Future<void> deleteCategory(int id) async {
    final cur = await sb.from('categories').select('*').eq('id', id).single();
    final curMajor = cur['major'] as String;
    final curSub = cur['sub'] as String;
    final usage = await sb
        .from('transactions')
        .select('id')
        .eq('major_category', curMajor)
        .eq('sub_category', curSub)
        .count(CountOption.exact);
    if (usage.count > 0) {
      throw Exception('이 태그를 사용하는 거래가 ${usage.count}건 있어 삭제할 수 없습니다.');
    }
    await sb.from('categories').delete().eq('id', id);
    categoriesVersion.value++;
  }

  // ── budgets ─────────────────────────────────────────────────
  Future<List<Budget>> listBudgets() async {
    final majorRows = await sb
        .from('majors')
        .select('major')
        .order('sort_order', ascending: true)
        .order('major', ascending: true);
    final rows = await sb.from('budgets').select('major, monthly_amount');
    final map = <String, int>{
      for (final r in rows as List)
        r['major'] as String: (r['monthly_amount'] as num?)?.toInt() ?? 0,
    };
    return (majorRows as List)
        .map((m) => Budget(
              major: m['major'] as String,
              monthlyAmount: map[m['major']] ?? 0,
            ))
        .toList();
  }

  Future<List<Budget>> saveBudgets(List<Budget> budgets) async {
    final userId = _uid();
    final validMajors =
        (await listMajors()).map((m) => m.name).toSet();
    final rows = budgets
        .where((b) => validMajors.contains(b.major))
        .map((b) => {
              'user_id': userId,
              'major': b.major,
              'monthly_amount': math.max(0, b.monthlyAmount),
            })
        .toList();
    if (rows.isNotEmpty) {
      await sb.from('budgets').upsert(rows, onConflict: 'user_id,major');
      budgetsVersion.value++;
    }
    return listBudgets();
  }

  // ── dashboard (클라이언트 계산) ─────────────────────────────
  Future<Dashboard> getDashboard([String? month]) async {
    final now = DateTime.now();
    final ym = month ?? _ymOf(now);
    final year = ym.substring(0, 4);
    final prev = _prevYm(ym);

    final results = await Future.wait([
      _getAllTx(),
      listMajors(),
      listBudgets(),
    ]);
    final txs = results[0] as List<Tx>;
    final majors = results[1] as List<Major>;
    final budgets = results[2] as List<Budget>;
    final budgetMap = {for (final b in budgets) b.major: b.monthlyAmount};

    final monthTxs = txs.where((t) => t.ym == ym).toList();
    final thisMonthTotal = monthTxs.fold<int>(0, (s, t) => s + t.amount);
    final prevMonthTotal = txs
        .where((t) => t.ym == prev)
        .fold<int>(0, (s, t) => s + t.amount);
    final fixedTotal = monthTxs
        .where((t) => t.isFixed)
        .fold<int>(0, (s, t) => s + t.amount);
    final variableTotal = monthTxs
        .where((t) => !t.isFixed)
        .fold<int>(0, (s, t) => s + t.amount);
    final yearTotal = txs
        .where((t) => t.year == year)
        .fold<int>(0, (s, t) => s + t.amount);

    int daysDivisor;
    if (ym == _ymOf(now)) {
      daysDivisor = now.day;
    } else {
      final parts = ym.split('-').map(int.parse).toList();
      daysDivisor = DateTime(parts[0], parts[1] + 1, 0).day;
    }
    final dailyAvg =
        daysDivisor > 0 ? (thisMonthTotal / daysDivisor).round() : 0;

    final perMajor = <String, _MajorAgg>{};
    for (final t in monthTxs) {
      final r = perMajor.putIfAbsent(t.majorCategory, () => _MajorAgg());
      r.spent += t.amount;
      r.count += 1;
      if (t.isFixed) {
        r.fixedSpent += t.amount;
      } else {
        r.variableSpent += t.amount;
      }
    }
    final categories = majors.map((m) {
      final r = perMajor[m.name] ?? _MajorAgg();
      return CategoryStats(
        major: m.name,
        spent: r.spent,
        fixedSpent: r.fixedSpent,
        variableSpent: r.variableSpent,
        count: r.count,
        budget: budgetMap[m.name] ?? 0,
      );
    }).toList();

    final trendMap = <String, int>{};
    for (final t in txs) {
      trendMap[t.ym] = (trendMap[t.ym] ?? 0) + t.amount;
    }
    final trendEntries = trendMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final trend = trendEntries
        .take(6)
        .toList()
        .reversed
        .map((e) => TrendPoint(ym: e.key, total: e.value))
        .toList();

    return Dashboard(
      month: ym,
      year: year,
      thisMonthTotal: thisMonthTotal,
      prevMonthTotal: prevMonthTotal,
      yearTotal: yearTotal,
      fixedTotal: fixedTotal,
      variableTotal: variableTotal,
      dailyAvg: dailyAvg,
      categories: categories,
      trend: trend,
    );
  }

  // ── stats (클라이언트 계산) ─────────────────────────────────
  Future<Suggestions> getSuggestions() async {
    final txs = await _getAllTx();
    final merchantCounts = <String, int>{};
    final cardCounts = <String, int>{};
    final byMajorCounts = <String, Map<String, int>>{};
    for (final t in txs) {
      final mer = t.merchant;
      if (mer != null && mer.isNotEmpty) {
        merchantCounts[mer] = (merchantCounts[mer] ?? 0) + 1;
        final m = byMajorCounts.putIfAbsent(t.majorCategory, () => {});
        m[mer] = (m[mer] ?? 0) + 1;
      }
      final card = t.card;
      if (card != null && card.isNotEmpty) {
        cardCounts[card] = (cardCounts[card] ?? 0) + 1;
      }
    }
    final merchants = merchantCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cards = cardCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final byMajor = <String, List<String>>{};
    byMajorCounts.forEach((maj, m) {
      final entries = m.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      byMajor[maj] = entries.take(20).map((e) => e.key).toList();
    });
    return Suggestions(
      merchants: merchants.take(200).map((e) => e.key).toList(),
      cards: cards.take(50).map((e) => e.key).toList(),
      merchantsByMajor: byMajor,
    );
  }

  Future<List<SubCategoryStat>> getSubCategoryStats({
    String? month,
    int limit = 10,
    bool? fixed,
  }) async {
    var txs = await _getAllTx();
    if (month != null) txs = txs.where((t) => t.ym == month).toList();
    txs = _filterFixed(txs, fixed);
    final map = <String, _SubAgg>{};
    for (final t in txs) {
      final sub = t.subCategory ?? '(태그 없음)';
      final key = '${t.majorCategory}|$sub';
      final r = map.putIfAbsent(
        key,
        () => _SubAgg(major: t.majorCategory, sub: sub),
      );
      r.count += 1;
      r.total += t.amount;
    }
    final list = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final cap = math.min(50, math.max(1, limit));
    return list
        .take(cap)
        .map((r) => SubCategoryStat(
              major: r.major,
              sub: r.sub,
              count: r.count,
              total: r.total,
            ))
        .toList();
  }

  // ── fixed expenses ──────────────────────────────────────────
  Future<List<FixedExpense>> listFixedExpenses() async {
    final rows = await sb
        .from('fixed_expenses')
        .select(
            'id, name, major, sub, amount, card, day_of_month, active, memo, sort_order')
        .order('active', ascending: false)
        .order('day_of_month', ascending: true)
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return (rows as List)
        .map((e) => FixedExpense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FixedExpense> createFixedExpense({
    required String name,
    required String major,
    String? sub,
    required int amount,
    String? card,
    int dayOfMonth = 1,
    bool active = true,
    String? memo,
  }) async {
    final userId = _uid();
    final n = name.trim();
    final m = major.trim();
    if (n.isEmpty || m.isEmpty) throw Exception('name, major 필수');
    final day = _clampDay(dayOfMonth);
    final maxRow = await sb
        .from('fixed_expenses')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    final next = ((maxRow?['sort_order'] as num?)?.toInt() ?? -1) + 1;
    final payload = {
      'user_id': userId,
      'name': n,
      'major': m,
      'sub': sub,
      'amount': math.max(0, amount),
      'card': card,
      'day_of_month': day,
      'active': active ? 1 : 0,
      'memo': memo,
      'sort_order': next,
    };
    final row = await sb
        .from('fixed_expenses')
        .insert(payload)
        .select()
        .single();
    fixedVersion.value++;
    return FixedExpense.fromJson(row);
  }

  Future<FixedExpense> updateFixedExpense(
    int id, {
    String? name,
    String? major,
    String? sub,
    int? amount,
    String? card,
    int? dayOfMonth,
    bool? active,
    String? memo,
  }) async {
    // 매칭용: 변경 전 값을 미리 알아둠 (이번 달 거래 동기화용).
    final cur = await sb
        .from('fixed_expenses')
        .select('name, major')
        .eq('id', id)
        .single();
    final oldName = cur['name'] as String;
    final oldMajor = cur['major'] as String;

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (major != null) payload['major'] = major.trim();
    if (sub != null) payload['sub'] = sub;
    if (amount != null) payload['amount'] = math.max(0, amount);
    if (card != null) payload['card'] = card;
    if (dayOfMonth != null) payload['day_of_month'] = _clampDay(dayOfMonth);
    if (active != null) payload['active'] = active ? 1 : 0;
    if (memo != null) payload['memo'] = memo;
    final row = await sb
        .from('fixed_expenses')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

    // 이번 달 매칭 거래 동기화 — 거래에 직접 영향 있는 필드만.
    // 과거 거래는 그대로 둠 (실제 발생액 보존).
    final txUpdate = <String, dynamic>{};
    if (name != null) txUpdate['merchant'] = name.trim();
    if (major != null) txUpdate['major_category'] = major.trim();
    if (sub != null) txUpdate['sub_category'] = sub;
    if (amount != null) txUpdate['amount'] = math.max(0, amount);
    if (card != null) txUpdate['card'] = card;
    if (txUpdate.isNotEmpty) {
      final ym = _ymOf(DateTime.now());
      await sb
          .from('transactions')
          .update(txUpdate)
          .eq('merchant', oldName)
          .eq('major_category', oldMajor)
          .eq('is_fixed', 1)
          .gte('date', '$ym-01')
          .lte('date', '$ym-31');
      invalidateTx();
    }

    fixedVersion.value++;
    return FixedExpense.fromJson(row);
  }

  Future<void> deleteFixedExpense(int id) async {
    await sb.from('fixed_expenses').delete().eq('id', id);
    fixedVersion.value++;
  }

  Future<FixedApplyResult> applyFixedExpenses(String month) async {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
      throw Exception('month는 YYYY-MM 형식이어야 합니다.');
    }
    final userId = _uid();
    final items = await sb.from('fixed_expenses').select('*').eq('active', 1);
    final existing = await sb
        .from('transactions')
        .select('merchant, major_category')
        .gte('date', '$month-01')
        .lte('date', '$month-31')
        .eq('is_fixed', 1);
    final existKey = <String>{
      for (final e in existing as List)
        '${e['merchant']}|${e['major_category']}',
    };
    final inserted = <FixedApplyEntry>[];
    final skipped = <FixedApplyEntry>[];
    final toInsert = <Map<String, dynamic>>[];
    for (final it in items as List) {
      final name = it['name'] as String;
      final major = it['major'] as String;
      final day = _clampDay(
        ((it['day_of_month'] as num?)?.toInt() ?? 1),
        month: month,
      );
      final date = '$month-${day.toString().padLeft(2, '0')}';
      final key = '$name|$major';
      if (existKey.contains(key)) {
        skipped.add(FixedApplyEntry(name: name, reason: '이미 등록됨'));
        continue;
      }
      toInsert.add({
        'user_id': userId,
        'date': date,
        'card': it['card'],
        'merchant': name,
        'amount': (it['amount'] as num?)?.toInt() ?? 0,
        'major_category': major,
        'sub_category': it['sub'],
        'memo': it['memo'],
        'is_fixed': 1,
      });
      inserted.add(FixedApplyEntry(
        name: name,
        date: date,
        amount: (it['amount'] as num?)?.toInt() ?? 0,
      ));
    }
    if (toInsert.isNotEmpty) {
      await sb.from('transactions').insert(toInsert);
      invalidateTx();
    }
    return FixedApplyResult(
      month: month,
      insertedCount: inserted.length,
      skippedCount: skipped.length,
      inserted: inserted,
      skipped: skipped,
    );
  }

  /// 모든 거래내역을 CSV 문자열로 export. 엑셀/구글 시트에서 바로 열림.
  /// 큰 따옴표/콤마/줄바꿈 escape 처리됨.
  Future<String> exportTransactionsCsv() async {
    final txs = await _getAllTx();
    final sorted = [...txs]..sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.id.compareTo(a.id);
      });
    final buf = StringBuffer()
      ..writeln('날짜,카드/결제수단,가맹점,금액,카테고리,태그,메모,고정비');
    for (final t in sorted) {
      buf.writeln([
        t.date,
        _csvField(t.card),
        _csvField(t.merchant),
        t.amount.toString(),
        _csvField(t.majorCategory),
        _csvField(t.subCategory),
        _csvField(t.memo),
        t.isFixed ? '예' : '아니오',
      ].join(','));
    }
    return buf.toString();
  }

  // ── AI 인사이트 (Edge Function 프록시) ─────────────────────
  /// 빠른 캐시 조회 — Edge Function 거치지 않고 ai_insights 테이블에서 바로
  /// 가져와서 분석 화면 마운트 시 즉시 표시용. RLS로 본인 데이터만 보임.
  Future<SpendingInsight?> getCachedSpendingInsight(String month) async {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) return null;
    final row = await sb
        .from('ai_insights')
        .select('content, generated_at')
        .eq('month', month)
        .maybeSingle();
    if (row == null) return null;
    final content = row['content'] as String?;
    if (content == null || content.isEmpty) return null;
    return SpendingInsight(
      text: content,
      cached: true,
      generatedAt: DateTime.tryParse(row['generated_at']?.toString() ?? ''),
    );
  }

  /// [force]가 true면 캐시 무시하고 새로 분석.
  /// 응답에는 insight 본문 + cached 여부 + (있다면) generated_at 포함.
  Future<SpendingInsight> getSpendingInsight(
    String month, {
    bool force = false,
  }) async {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
      throw Exception('month 필요');
    }
    final res = await sb.functions.invoke(
      'spending-insights',
      body: {'month': month, 'force': force},
    );
    final data = res.data;
    if (data is Map && data['insight'] is String) {
      return SpendingInsight(
        text: data['insight'] as String,
        cached: data['cached'] == true,
        generatedAt: data['generatedAt'] is String
            ? DateTime.tryParse(data['generatedAt'] as String)
            : null,
      );
    }
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    throw Exception('분석 결과를 받을 수 없어요.');
  }

  Future<PendingFixed> getPendingFixedExpenses(String month) async {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
      throw Exception('month 필요');
    }
    final items =
        await sb.from('fixed_expenses').select('name, major').eq('active', 1);
    final existing = await sb
        .from('transactions')
        .select('merchant, major_category')
        .gte('date', '$month-01')
        .lte('date', '$month-31')
        .eq('is_fixed', 1);
    final existKey = <String>{
      for (final e in existing as List)
        '${e['merchant']}|${e['major_category']}',
    };
    var pending = 0;
    for (final it in items as List) {
      if (!existKey.contains('${it['name']}|${it['major']}')) pending++;
    }
    return PendingFixed(
      month: month,
      total: (items as List).length,
      pending: pending,
    );
  }
}

// ── 헬퍼 ────────────────────────────────────────────────────────

String _ymOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

String _prevYm(String ym) {
  final parts = ym.split('-').map(int.parse).toList();
  final d = DateTime(parts[0], parts[1] - 1, 1);
  return _ymOf(d);
}

int _clampDay(int day, {String? month}) {
  final d = day.clamp(1, 31);
  if (month == null) return d;
  final parts = month.split('-').map(int.parse).toList();
  final lastDay = DateTime(parts[0], parts[1] + 1, 0).day;
  return math.min(d, lastDay);
}

/// CSV 한 필드 escape — 콤마/큰따옴표/줄바꿈 포함 시 큰따옴표로 감쌈.
String _csvField(String? v) {
  if (v == null || v.isEmpty) return '';
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

List<Tx> _filterFixed(List<Tx> txs, bool? fixed) {
  if (fixed == true) return txs.where((t) => t.isFixed).toList();
  if (fixed == false) return txs.where((t) => !t.isFixed).toList();
  return txs;
}

class SpendingInsight {
  const SpendingInsight({
    required this.text,
    required this.cached,
    this.generatedAt,
  });
  final String text;
  final bool cached;
  final DateTime? generatedAt;
}

class _MajorAgg {
  int spent = 0;
  int fixedSpent = 0;
  int variableSpent = 0;
  int count = 0;
}

class _SubAgg {
  final String major;
  final String sub;
  int count = 0;
  int total = 0;
  _SubAgg({required this.major, required this.sub});
}

