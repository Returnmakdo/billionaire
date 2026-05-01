import 'package:flutter/foundation.dart';

import '../widgets/format.dart';

/// 화면 간 공유되는 선택된 월 (YYYY-MM).
/// 대시보드/거래내역 등이 같은 값을 읽고 쓰므로, 한 화면에서 월 바꾸면
/// 다른 화면도 자동으로 같은 월을 보여줌.
class SelectedMonth {
  SelectedMonth._();
  static final ValueNotifier<String> value = ValueNotifier(todayYm());
}
