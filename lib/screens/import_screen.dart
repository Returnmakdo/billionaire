import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../api/api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../utils/csv_download_stub.dart'
    if (dart.library.html) '../utils/csv_download_web.dart';
import '../utils/is_mobile_stub.dart'
    if (dart.library.html) '../utils/is_mobile_web.dart';
import '../utils/nav_back.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// 설정 → 데이터 가져오기. CSV 파일을 받아 거래로 일괄 등록.
/// 1) 템플릿 CSV 다운로드 → 2) 채워서 업로드 → 3) 미리보기 → 4) 가져오기.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<ImportRow>? _rows;
  String? _fileName;
  List<String> _errors = [];
  bool _importing = false;

  // 필수 컬럼(날짜/금액/카테고리)을 앞에 모아서 사용자가 한눈에 알아보게.
  static const _csvHeader =
      '날짜,금액,카테고리,가맹점,카드/결제수단,태그,메모,고정비';
  static const _csvTemplate = '$_csvHeader\n'
      '2026-05-01,5800,식비/카페,스타벅스,신한카드,카페,,아니오\n'
      '2026-05-01,18500,식비/카페,쿠팡이츠,,배달,점심,아니오\n'
      '2026-05-01,700000,주거,월세,국민카드,월세,,예\n';

  static const _webUrl = 'https://billionaire-chi.vercel.app/settings/import';

  Future<void> _downloadTemplate() async {
    // 반환 true = share dialog로 처리됨 (사용자가 시트 봤으니 toast 불필요).
    // false = 브라우저 다운로드 (사용자에게 명시적으로 알림).
    final shared = await triggerCsvDownload(
      _csvTemplate,
      '가계부_가져오기_템플릿.csv',
    );
    if (!mounted) return;
    if (!shared) showToast(context, '템플릿을 다운로드했어요');
  }

  Future<void> _copyWebUrl() async {
    await Clipboard.setData(const ClipboardData(text: _webUrl));
    if (mounted) showToast(context, 'URL을 복사했어요');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) showToast(context, '파일을 읽을 수 없어요', error: true);
      return;
    }

    // BOM 제거 + UTF-8 시도, 실패하면 EUC-KR(latin1로 대체) — 한국 카드사 일부.
    String text;
    try {
      text = utf8.decode(_stripBom(bytes));
    } catch (_) {
      text = latin1.decode(bytes);
    }

    final parsed = _parseCsv(text);
    if (!mounted) return;
    setState(() {
      _fileName = file.name;
      _rows = parsed.rows;
      _errors = parsed.errors;
    });
  }

  List<int> _stripBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  _ParseResult _parseCsv(String text) {
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) {
      return const _ParseResult(rows: [], errors: ['파일이 비어있어요']);
    }
    final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
    if (dataLines.isEmpty) {
      return const _ParseResult(rows: [], errors: ['데이터 행이 없어요']);
    }

    final rows = <ImportRow>[];
    final errors = <String>[];
    for (var i = 0; i < dataLines.length; i++) {
      final lineNo = i + 2; // 헤더가 1행
      try {
        final fields = _parseCsvLine(dataLines[i]);
        // 필수 컬럼 3개 (날짜/금액/카테고리)
        if (fields.length < 3) {
          errors.add('$lineNo행: 컬럼이 부족해요 (날짜·금액·카테고리 필수)');
          continue;
        }
        final date = _normalizeDate(fields[0]);
        if (date == null) {
          errors.add('$lineNo행: 날짜 형식이 잘못됐어요 (예: 2026-05-01)');
          continue;
        }
        final amountStr = _get(fields, 1);
        final amount = _parseAmount(amountStr);
        if (amount == null || amount <= 0) {
          errors.add('$lineNo행: 금액이 잘못됐어요 ("$amountStr")');
          continue;
        }
        final major = _get(fields, 2).trim();
        if (major.isEmpty) {
          errors.add('$lineNo행: 카테고리는 필수예요');
          continue;
        }
        final merchant = _emptyToNull(_get(fields, 3));
        final card = _emptyToNull(_get(fields, 4));
        final sub = _emptyToNull(_get(fields, 5));
        final memo = _emptyToNull(_get(fields, 6));
        final fixedStr = _get(fields, 7).trim();
        final isFixed = fixedStr == '예' ||
            fixedStr.toLowerCase() == 'y' ||
            fixedStr.toLowerCase() == 'true' ||
            fixedStr == '1';

        rows.add(ImportRow(
          date: date,
          card: card,
          merchant: merchant,
          amount: amount,
          majorCategory: major,
          subCategory: sub,
          memo: memo,
          isFixed: isFixed,
        ));
      } catch (e) {
        errors.add('$lineNo행: $e');
      }
    }
    return _ParseResult(rows: rows, errors: errors);
  }

  String _get(List<String> fields, int i) =>
      i < fields.length ? fields[i] : '';

  String? _emptyToNull(String? v) {
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  /// 큰따옴표 escape 지원하는 CSV 한 줄 파서.
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuote) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuote = false;
          }
        } else {
          buf.write(ch);
        }
      } else {
        if (ch == ',') {
          result.add(buf.toString());
          buf.clear();
        } else if (ch == '"') {
          inQuote = true;
        } else {
          buf.write(ch);
        }
      }
    }
    result.add(buf.toString());
    return result;
  }

  /// "2026-05-01", "2026/5/1", "2026.05.01" 등 → "2026-05-01".
  String? _normalizeDate(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[./]'), '-');
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(cleaned);
    if (m == null) return null;
    final y = m.group(1)!;
    final mo = m.group(2)!.padLeft(2, '0');
    final d = m.group(3)!.padLeft(2, '0');
    return '$y-$mo-$d';
  }

  /// "5,800원", "5800", "5,800" 등 → 5800.
  int? _parseAmount(String s) {
    final cleaned = s.replaceAll(RegExp(r'[,\s원]'), '');
    return int.tryParse(cleaned);
  }

  Future<void> _import() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return;
    setState(() => _importing = true);
    try {
      final n = await Api.instance.importTransactions(rows);
      if (!mounted) return;
      showToast(context, '$n건을 등록했어요');
      setState(() {
        _rows = null;
        _fileName = null;
        _errors = [];
      });
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

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
          '데이터 가져오기',
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
            _stepCard(
              step: '1',
              title: '템플릿 받기',
              body: !isMobileEnv()
                  ? '빈 양식 + 예시가 들어있는 CSV 파일을 받으세요. 엑셀에서 열어 거래 내역을 채우면 돼요.'
                  : '템플릿 CSV를 다른 앱(메일·카카오톡·구글드라이브 등)으로 공유해서 PC에서 받을 수 있어요. 또는 아래 PC 웹 URL로 직접 받으세요.',
              action: OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: Icon(
                  !isMobileEnv() ? Icons.download : Icons.ios_share,
                  size: 18,
                ),
                label: Text(!isMobileEnv() ? '템플릿 받기' : '템플릿 공유'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primaryWeak, width: 1.5),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            if (isMobileEnv()) ...[
              const SizedBox(height: 8),
              _webUrlCard(),
            ],
            const SizedBox(height: 12),
            _stepCard(
              step: '2',
              title: '파일 선택',
              body: '채운 CSV 파일을 선택하세요. '
                  'UTF-8로 저장하면 한글이 안 깨져요.',
              action: FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('파일 선택'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            if (_rows != null) ...[
              const SizedBox(height: 12),
              _previewCard(),
            ],
            const SizedBox(height: 18),
            _formatGuide(),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String step,
    required String title,
    required String body,
    Widget? action,
  }) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text2,
              height: 1.55,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }

  Widget _previewCard() {
    final rows = _rows!;
    final hasErrors = _errors.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 18, color: AppColors.text2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _fileName ?? '미리보기',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '읽은 거래 ${rows.length}건${hasErrors ? ' · 건너뛴 행 ${_errors.length}개' : ''}',
            style: TextStyle(fontSize: 12.5, color: AppColors.text3),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.line2, height: 1),
            const SizedBox(height: 8),
            // 첫 5건만 미리보기
            for (final r in rows.take(5)) _previewRow(r),
            if (rows.length > 5) ...[
              const SizedBox(height: 4),
              Text(
                '… 외 ${rows.length - 5}건',
                style: TextStyle(
                    fontSize: 12, color: AppColors.text3),
              ),
            ],
          ],
          if (hasErrors) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in _errors.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '· $e',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          height: 1.5,
                        ),
                      ),
                    ),
                  if (_errors.length > 5)
                    Text(
                      '… 외 ${_errors.length - 5}건',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.danger),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: rows.isEmpty || _importing ? null : _import,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(_importing
                ? '등록 중...'
                : '${rows.length}건 등록하기'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(ImportRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            r.date,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.merchant ?? '(가맹점 없음)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${won(r.amount)}원',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _webUrlCard() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryWeak,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 16, color: AppColors.primaryStrong),
              SizedBox(width: 6),
              Text(
                'PC 웹에서 작업하기를 추천해요',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '모바일에서도 가능하지만, 엑셀로 거래 정리하는 건 PC에서 훨씬 편해요. 아래 URL을 복사해서 PC 브라우저에 붙여넣으세요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _copyWebUrl,
              icon: const Icon(Icons.content_copy, size: 14),
              label: const Text('URL 복사'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryStrong,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatGuide() {
    return AppCard(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: AppColors.primaryStrong),
              SizedBox(width: 8),
              Text(
                'CSV 양식 안내',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '필수',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          _guideRow('날짜', 'YYYY-MM-DD (예: 2026-05-01)', required: true),
          _guideRow('금액', '숫자, 콤마/원 OK', required: true),
          _guideRow('카테고리', '새 카테고리면 자동 추가됨', required: true),
          const SizedBox(height: 14),
          Text(
            '선택',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text3,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          _guideRow('가맹점', '거래처 이름'),
          _guideRow('카드/결제수단', '예: 신한카드'),
          _guideRow('태그', '카테고리 하위, 새 태그면 자동 추가됨'),
          _guideRow('메모', '자유 텍스트'),
          _guideRow('고정비', '"예" 또는 "아니오" (기본 아니오)'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '카드사 명세서 → 엑셀 → 템플릿 양식대로 정리 → 저장(CSV UTF-8) → 가져오기',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.text3,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideRow(String name, String desc, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (required)
            Container(
              margin: const EdgeInsets.only(top: 1, right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '필수',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: required ? FontWeight.w700 : FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.text3,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParseResult {
  const _ParseResult({required this.rows, required this.errors});
  final List<ImportRow> rows;
  final List<String> errors;
}
