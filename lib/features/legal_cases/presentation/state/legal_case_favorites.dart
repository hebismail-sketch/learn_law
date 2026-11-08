import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/legal_case_entity.dart';

class LegalCaseFavorites extends ChangeNotifier {
  LegalCaseFavorites._();

  static const _casesPreferenceKey = 'favorite_legal_cases';
  static const _categoriesPreferenceKey = 'favorite_category_ids';
  static final instance = LegalCaseFavorites._();

  final Map<String, LegalCaseEntity> _favorites = {};
  final Set<String> _favoriteCategoryIds = {};
  SharedPreferences? _preferences;

  List<LegalCaseEntity> get cases =>
      List<LegalCaseEntity>.unmodifiable(_favorites.values);

  Set<String> get categoryIds => Set<String>.unmodifiable(_favoriteCategoryIds);

  bool contains(String caseId) => _favorites.containsKey(caseId);

  bool containsCategory(String categoryId) =>
      _favoriteCategoryIds.contains(categoryId);

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = await _decodeCases(
      preferences.getString(_casesPreferenceKey),
      preferences,
    );

    _preferences = preferences;
    _favorites
      ..clear()
      ..addAll(favorites);
    _favoriteCategoryIds
      ..clear()
      ..addAll(preferences.getStringList(_categoriesPreferenceKey) ?? []);
    notifyListeners();
  }

  Future<bool> toggle(LegalCaseEntity legalCase) async {
    final preferences = _getPreferences();
    final nextFavorites = Map<String, LegalCaseEntity>.of(_favorites);
    final isFavorite = nextFavorites.remove(legalCase.id) == null;
    if (isFavorite) nextFavorites[legalCase.id] = legalCase;

    final saved = await preferences.setString(
      _casesPreferenceKey,
      jsonEncode(nextFavorites.values.map(_encodeCase).toList()),
    );
    if (!saved) throw StateError('Could not save legal case favorites.');

    _favorites
      ..clear()
      ..addAll(nextFavorites);
    notifyListeners();
    return isFavorite;
  }

  Future<bool> toggleCategory(String categoryId) async {
    final preferences = _getPreferences();
    final nextIds = Set<String>.of(_favoriteCategoryIds);
    final isFavorite = !nextIds.remove(categoryId);
    if (isFavorite) nextIds.add(categoryId);

    final saved = await preferences.setStringList(
      _categoriesPreferenceKey,
      nextIds.toList(),
    );
    if (!saved) throw StateError('Could not save category favorites.');

    _favoriteCategoryIds
      ..clear()
      ..addAll(nextIds);
    notifyListeners();
    return isFavorite;
  }

  SharedPreferences _getPreferences() =>
      _preferences ??
      (throw StateError('Legal case favorites have not been initialized.'));

  Map<String, dynamic> _encodeCase(LegalCaseEntity legalCase) => {
    'id': legalCase.id,
    'subcategoryId': legalCase.subcategoryId,
    'name': legalCase.name,
    'description': legalCase.description,
  };

  Future<Map<String, LegalCaseEntity>> _decodeCases(
    String? value,
    SharedPreferences preferences,
  ) async {
    if (value == null) return {};

    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        throw const FormatException('Expected a list of saved cases.');
      }

      final favorites = <String, LegalCaseEntity>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            item['subcategoryId'] is! String ||
            item['name'] is! String ||
            (item['description'] != null && item['description'] is! String)) {
          debugPrint('Skipping malformed saved favorite: $item');
          continue;
        }

        final legalCase = LegalCaseEntity(
          id: item['id'] as String,
          subcategoryId: item['subcategoryId'] as String,
          name: item['name'] as String,
          description: item['description'] as String?,
        );
        favorites[legalCase.id] = legalCase;
      }
      return favorites;
    } on FormatException catch (error, stackTrace) {
      debugPrint('Saved legal case favorites are invalid: $error\n$stackTrace');
      final removed = await preferences.remove(_casesPreferenceKey);
      if (!removed) {
        debugPrint('Could not clear invalid saved legal case favorites.');
      }
      return {};
    }
  }
}
