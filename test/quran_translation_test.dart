import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/quran_translation.dart';
import 'package:adhkar_app/l10n/strings.dart';

/// The app offers ten interface languages. A language with no translation
/// entry silently shows nothing at all under the ayah — no error, no gap
/// anyone would notice in testing — so the parity check is what makes a
/// forgotten language loud.
void main() {
  test('every language the app ships can show a translation, except Arabic', () {
    for (final s in AppStrings.all) {
      final choice = QuranTranslation.forLanguage(s.code);
      if (s.code == 'ar') {
        // Not an omission. The Arabic is the Quran; there is nothing to
        // translate it into for an Arabic reader.
        expect(choice, isNull,
            reason: 'Arabic must not carry a translation of the meanings');
        continue;
      }
      expect(choice, isNotNull, reason: '${s.code} has no translation chosen');
      expect(choice!.editionId, greaterThan(0));
      expect(choice.translator.trim(), isNotEmpty,
          reason: '${s.code} translation must name its translator');
    }
  });

  test('no two languages point at the same edition', () {
    final ids = QuranTranslation.languages
        .map((l) => QuranTranslation.forLanguage(l)!.editionId)
        .toList();
    expect(ids.toSet().length, ids.length,
        reason: 'a duplicated edition id means a language was miscopied');
  });

  test('the translation list covers exactly the non-Arabic languages', () {
    final shipped = AppStrings.all.map((s) => s.code).toSet()..remove('ar');
    expect(QuranTranslation.languages.toSet(), shipped);
  });
}
