import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/adhkar_data.dart';
import 'package:adhkar_app/l10n/strings.dart';

/// The app offers ten languages. A key added to Arabic and forgotten
/// elsewhere does not crash — `get` silently falls back to Arabic — so a
/// half-translated screen would ship looking fine in testing and wrong to
/// everyone else. These tests are what makes that loud.
void main() {
  final arabic = AppStrings.of('ar');

  test('every language carries every key that Arabic does', () {
    for (final s in AppStrings.all) {
      for (final key in AppStrings.keys) {
        expect(s.get(key), isNotEmpty, reason: '${s.code} is missing "$key"');
        if (s.code == 'ar') continue;
        // A non-Arabic language repeating the Arabic word verbatim means the
        // key was never actually translated. Proper nouns are exempt.
        const sharedWords = {'tafsir', 'juz', 'hizb', 'mushaf', 'qibla'};
        if (sharedWords.contains(key)) continue;
        if (s.direction == arabic.direction) continue; // Urdu shares script
        expect(s.get(key), isNot(arabic.get(key)),
            reason: '${s.code} "$key" is still the Arabic text');
      }
    }
  });

  test('every prayer in the schedule has a name in every language', () {
    const scheduleNames = ['الفجر', 'الضحى', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    for (final s in AppStrings.all) {
      for (final name in scheduleNames) {
        final shown = s.prayer(name);
        expect(shown, isNotEmpty);
        if (s.code != 'ar' && s.direction != arabic.direction) {
          expect(shown, isNot(name), reason: '${s.code} shows "$name" untranslated');
        }
      }
    }
  });

  test('every adhkar category has a name in every language', () {
    for (final s in AppStrings.all) {
      for (final c in catalog) {
        expect(s.category(c.key), isNotEmpty,
            reason: '${s.code} is missing category "${c.key}"');
        expect(s.category(c.key), isNot('c_${c.key}'),
            reason: '${s.code} category "${c.key}" fell through to its key');
      }
    }
  });

  test('the language list is what the picker offers', () {
    expect(AppStrings.all.length, 10);
    expect(AppStrings.locales.length, AppStrings.all.length);
    for (final s in AppStrings.all) {
      expect(AppStrings.supports(s.code), isTrue);
      expect(s.nativeName, isNotEmpty);
    }
  });
}
