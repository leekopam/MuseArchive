import 'package:flutter/foundation.dart';
import '../viewmodels/artist_viewmodel.dart';

/// 아티스트 화면의 전역 설정을 관리하는 프로바이더
class GlobalArtistSettings extends ChangeNotifier {
  // 기본값: 내림차순 (최신순)
  SortOrder _sortOrder = SortOrder.desc;

  SortOrder get sortOrder => _sortOrder;

  void setSortOrder(SortOrder order) {
    if (_sortOrder != order) {
      _sortOrder = order;
      notifyListeners();
    }
  }

  void toggleSortOrder() {
    _sortOrder = _sortOrder == SortOrder.asc ? SortOrder.desc : SortOrder.asc;
    notifyListeners();
  }
}
