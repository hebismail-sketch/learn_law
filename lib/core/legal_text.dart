import 'dart:convert';

final RegExp legalTextSymbolPattern = RegExp(
  r'[^\p{L}\p{N}\p{M}\s.,،؛؟!:;…]',
  unicode: true,
);

String stripLegalTextSymbols(String text) =>
    text.replaceAll(legalTextSymbolPattern, '');

String stripLegalTextSymbolsFromStepDescription(String text) {
  const branchesPrefix = '__BRANCHES_JSON__';
  if (!text.startsWith(branchesPrefix)) return stripLegalTextSymbols(text);

  try {
    final decoded = jsonDecode(text.substring(branchesPrefix.length));
    return '$branchesPrefix${jsonEncode(_stripTextFromJson(decoded))}';
  } on FormatException {
    return stripLegalTextSymbols(text);
  }
}

Object? _stripTextFromJson(Object? value) {
  if (value is String) return stripLegalTextSymbols(value);
  if (value is List) return value.map(_stripTextFromJson).toList();
  if (value is Map<String, dynamic>) {
    return value.map((key, value) => MapEntry(key, _stripTextFromJson(value)));
  }
  return value;
}
