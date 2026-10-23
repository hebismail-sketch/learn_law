import 'package:flutter/foundation.dart';

import '../../domain/entities/legal_case_entity.dart';

class LegalCaseFavorites extends ChangeNotifier {
  LegalCaseFavorites._();

  static final instance = LegalCaseFavorites._();

  final Map<String, LegalCaseEntity> _favorites = {};

  List<LegalCaseEntity> get cases =>
      List<LegalCaseEntity>.unmodifiable(_favorites.values);

  bool contains(String caseId) => _favorites.containsKey(caseId);

  bool toggle(LegalCaseEntity legalCase) {
    if (_favorites.remove(legalCase.id) != null) {
      notifyListeners();
      return false;
    }

    _favorites[legalCase.id] = legalCase;
    notifyListeners();
    return true;
  }
}
