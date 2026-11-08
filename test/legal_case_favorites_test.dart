import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/domain/entities/legal_case_entity.dart';
import 'package:learn_law/features/legal_cases/presentation/state/legal_case_favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LegalCaseFavorites.instance.initialize();
  });

  test('restores case and category favorites after reinitialization', () async {
    final legalCase = LegalCaseEntity(
      id: 'case-1',
      subcategoryId: 'subcategory-1',
      name: 'دعوى نفقة',
      description: 'إجراءات دعوى النفقة',
    );

    expect(await LegalCaseFavorites.instance.toggle(legalCase), isTrue);
    expect(
      await LegalCaseFavorites.instance.toggleCategory('category-1'),
      isTrue,
    );

    await LegalCaseFavorites.instance.initialize();

    expect(LegalCaseFavorites.instance.contains(legalCase.id), isTrue);
    expect(LegalCaseFavorites.instance.cases.single.name, legalCase.name);
    expect(
      LegalCaseFavorites.instance.cases.single.description,
      legalCase.description,
    );
    expect(LegalCaseFavorites.instance.containsCategory('category-1'), isTrue);

    expect(await LegalCaseFavorites.instance.toggle(legalCase), isFalse);
    expect(
      await LegalCaseFavorites.instance.toggleCategory('category-1'),
      isFalse,
    );
    await LegalCaseFavorites.instance.initialize();

    expect(LegalCaseFavorites.instance.cases, isEmpty);
    expect(LegalCaseFavorites.instance.categoryIds, isEmpty);
  });
}
