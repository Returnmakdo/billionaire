// CSV/XLSX 디코딩 + 파싱 유틸. 카드사 양식이 다양해서 여기선 raw 파싱만 담당.
// 컬럼 매핑은 AI(import-csv-assist)에 위임.

import 'dart:convert';

import 'package:excel/excel.dart';

class CsvFile {
  final List<String> headers;
  final List<List<String>> rows;
  const CsvFile({required this.headers, required this.rows});
}

class CsvParseError implements Exception {
  final String message;
  CsvParseError(this.message);
  @override
  String toString() => 'CsvParseError: $message';
}

/// 바이트를 디코드. UTF-8(BOM 처리) 우선, 실패 시 latin1 fallback.
/// 한국 카드사 CSV가 CP949(EUC-KR)인 경우 latin1 fallback에선 한글이 깨짐 —
/// 그 경우 사용자에게 UTF-8로 다시 저장 안내가 필요.
String decodeCsvBytes(List<int> bytes) {
  final stripped = _stripBom(bytes);
  try {
    return utf8.decode(stripped, allowMalformed: false);
  } catch (_) {
    return latin1.decode(stripped);
  }
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

/// 한글이 깨졌는지 휴리스틱 — latin1 fallback 후 0x80~0xFF 영역의 깨진 문자가
/// 많으면 true. 사용자 안내용.
bool looksMojibake(String text) {
  if (text.isEmpty) return false;
  var suspicious = 0;
  var total = 0;
  for (final r in text.runes) {
    total++;
    if (r >= 0x80 && r < 0x100) suspicious++;
    if (total > 2000) break;
  }
  return total > 50 && suspicious / total > 0.15;
}

/// CSV 텍스트를 헤더 + rows로 파싱.
/// - 큰따옴표 escape 처리
/// - 빈 줄 무시
/// - 첫 번째 비어있지 않은 줄을 헤더로 사용
CsvFile parseCsv(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    throw CsvParseError('파일이 비어있어요');
  }
  final headers = parseCsvLine(lines.first);
  final rows = <List<String>>[];
  for (var i = 1; i < lines.length; i++) {
    rows.add(parseCsvLine(lines[i]));
  }
  return CsvFile(headers: headers, rows: rows);
}

/// 큰따옴표 escape 지원하는 CSV 한 줄 파서.
List<String> parseCsvLine(String line) {
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

/// XLSX 바이트 → CsvFile (첫 번째 sheet의 데이터만).
/// 첫 번째 비어있지 않은 행을 헤더로 사용. 셀은 toString()으로 변환.
/// .xls(BIFF) 구버전은 excel 패키지에서 지원 안 함 — 그 경우 throw.
CsvFile parseXlsxBytes(List<int> bytes) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (e) {
    throw CsvParseError(
        'XLSX를 읽지 못했어요. 엑셀에서 .xlsx로 다시 저장해주세요. ($e)');
  }
  if (book.tables.isEmpty) {
    throw CsvParseError('시트가 없어요.');
  }
  final firstSheet = book.tables.values.first;
  final allRows = <List<String>>[];
  for (final row in firstSheet.rows) {
    final cells = row.map((cell) => _cellToString(cell)).toList();
    if (cells.every((c) => c.trim().isEmpty)) continue;
    allRows.add(cells);
  }
  if (allRows.isEmpty) {
    throw CsvParseError('데이터 행이 없어요.');
  }
  // trailing 빈 컬럼 제거 (엑셀 sheet의 빈 우측 컬럼 잘라내기).
  var maxCol = 0;
  for (final r in allRows) {
    for (var i = r.length - 1; i >= 0; i--) {
      if (r[i].trim().isNotEmpty) {
        if (i + 1 > maxCol) maxCol = i + 1;
        break;
      }
    }
  }
  if (maxCol > 0) {
    for (var i = 0; i < allRows.length; i++) {
      if (allRows[i].length > maxCol) {
        allRows[i] = allRows[i].sublist(0, maxCol);
      }
    }
  }
  final headers = allRows.first;
  final rows = allRows.skip(1).toList();
  return CsvFile(headers: headers, rows: rows);
}

String _cellToString(Data? cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  if (v is DateCellValue) {
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
  if (v is DateTimeCellValue) {
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
  if (v is TextCellValue) {
    return v.value.text ?? '';
  }
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) {
    final d = v.value;
    if (d == d.truncate()) return d.toInt().toString();
    return d.toString();
  }
  if (v is BoolCellValue) return v.value ? 'true' : 'false';
  if (v is FormulaCellValue) return v.formula;
  return v.toString();
}

/// 다양한 날짜 포맷을 YYYY-MM-DD로 정규화.
/// dateFormat: AI가 추정한 형식 힌트 ("YYYY-MM-DD" "YYYY/MM/DD" "YYYY.MM.DD"
/// "YYYYMMDD" "MM/DD/YYYY" 등). null이면 휴리스틱.
String? normalizeDate(String s, {String? dateFormat}) {
  final t = s.trim();
  if (t.isEmpty) return null;

  final fmt = dateFormat?.toUpperCase();

  // YYYYMMDD (구분자 없음) 우선 처리.
  if (fmt == 'YYYYMMDD' || fmt == null || fmt == 'AUTO') {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(t);
    if (m != null) return '${m.group(1)}-${m.group(2)}-${m.group(3)}';
  }

  // 한국어 표기: "2026년 4월 25일" / "2026년04월25일"
  final ko = RegExp(r'^(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일')
      .firstMatch(t);
  if (ko != null) {
    final y = ko.group(1)!;
    final mo = ko.group(2)!.padLeft(2, '0');
    final d = ko.group(3)!.padLeft(2, '0');
    return '$y-$mo-$d';
  }

  // 구분자 통일 (./ → -). 시간 부분이 붙어 있어도 날짜만 잡음.
  final cleaned = t.replaceAll(RegExp(r'[./]'), '-');

  // MM-DD-YYYY (미국식)
  if (fmt == 'MM/DD/YYYY' || fmt == 'MM-DD-YYYY' || fmt == 'M/D/YYYY') {
    final m = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})').firstMatch(cleaned);
    if (m != null) {
      final mo = m.group(1)!.padLeft(2, '0');
      final d = m.group(2)!.padLeft(2, '0');
      final y = m.group(3)!;
      return '$y-$mo-$d';
    }
  }

  // YYYY-MM-DD 또는 YYYY-M-D
  final ym = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(cleaned);
  if (ym != null) {
    final y = ym.group(1)!;
    final mo = ym.group(2)!.padLeft(2, '0');
    final d = ym.group(3)!.padLeft(2, '0');
    return '$y-$mo-$d';
  }

  return null;
}

/// "5,800원", "-5,800", "(5,800)" 등을 정수로.
/// amountSign:
///  - "absolute": 부호 무시 절대값 (기본).
///  - "negative": 출금이 음수인 카드사 — 음수만 양수로 변환, 양수는 입금이라 null 리턴.
///  - "positive": 양수만 받고 음수는 null.
int? parseAmount(String s, {String amountSign = 'absolute'}) {
  final t = s.trim();
  if (t.isEmpty) return null;

  // 괄호로 음수 표시 ((5,800) → -5800).
  var working = t;
  var bracketed = false;
  if (working.startsWith('(') && working.endsWith(')')) {
    bracketed = true;
    working = working.substring(1, working.length - 1);
  }
  final cleaned = working.replaceAll(RegExp(r'[,\s원₩]'), '');
  final n = int.tryParse(cleaned);
  if (n == null) return null;
  final signed = bracketed ? -n.abs() : n;

  switch (amountSign) {
    case 'negative':
      if (signed < 0) return -signed;
      return null;
    case 'positive':
      if (signed > 0) return signed;
      return null;
    case 'absolute':
    default:
      return signed.abs();
  }
}
