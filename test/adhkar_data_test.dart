import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/adhkar_data.dart';

/// Guards the generated adhkar. These do not — and cannot — verify that the
/// content is religiously sound; that needs a person who knows the material.
/// What they catch is the generator silently mangling it: empty entries,
/// count notes left in the text, or a category quietly emptying out.

/// Diacritic-free form for matching. The class is written as explicit code
/// points on purpose: spelling it with literal characters yields the range
/// U+061A-U+0670, which strips Arabic *letters* as well and makes every
/// comparison below trivially true.
final _marks = RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');

String bare(String text) => text
    .replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي');

void main() {
  _translationChecks();
  _completenessChecks();
  test('every catalogued category has content', () {
    for (final meta in catalog) {
      final items = adhkarSets[meta.key];
      expect(items, isNotNull, reason: '${meta.key} is in the catalog but has no list');
      expect(items, isNotEmpty, reason: '${meta.key} is empty');
    }
  });

  test('no empty or truncated text', () {
    for (final entry in adhkarSets.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final text = entry.value[i].text;
        expect(text.trim(), isNotEmpty, reason: '${entry.key}[$i] is empty');
        // The shortest real dhikr in the book is still a full phrase; a
        // handful of characters means the cleaner ate the entry.
        expect(text.length, greaterThan(10), reason: '${entry.key}[$i] looks truncated: "$text"');
        expect(text, isNot(startsWith('(')), reason: '${entry.key}[$i] kept a stray paren');
      }
    }
  });

  test('repetition counts are sane and the known ones are right', () {
    for (final entry in adhkarSets.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final count = entry.value[i].count;
        expect(count, greaterThanOrEqualTo(1), reason: '${entry.key}[$i] has count $count');
        expect(count, lessThanOrEqualTo(100), reason: '${entry.key}[$i] has count $count');
      }
    }

    // Spot-checks on counts the book states in words. The API's own REPEAT
    // field reports 1 for "حسبي الله" despite the text saying seven times,
    // which is why the generator reads the count out of the wording.
    // Matched without diacritics: the source's vowel marks do not line up
    final morning = adhkarSets['morning']!;
    final hasbi = morning.firstWhere(
        (d) => bare(d.text).contains('حسبي الله'));
    expect(hasbi.count, 7);

    expect(morning.where((d) => d.count == 100), isNotEmpty,
        reason: 'the hundred-times adhkar should survive generation');
  });

  test('the count note is stripped out of the text', () {
    // "(ثلاث مرات)" belongs in `count`; leaving it in the body duplicates it
    // on screen beside the live counter.
    // Explicit code points: the literal form of this class parses as
    // U+061A-U+0670 and strips Arabic letters too.
    for (final entry in adhkarSets.entries) {
      for (final item in entry.value) {
        final flat = bare(item.text);
        expect(flat.contains(RegExp(r'\([^)]*(مرات|مره)[^)]*\)\s*$')), isFalse,
            reason: '${entry.key} still carries a count note: "${item.text}"');
      }
    }
  });

  test('morning and evening are distinct lists', () {
    final morning = adhkarSets['morning']!.map((d) => d.text).toList();
    final evening = adhkarSets['evening']!.map((d) => d.text).toList();
    expect(morning, isNotEmpty);
    expect(evening, isNotEmpty);
    // The evening wording differs for at least the "أصبحنا/أمسينا" family.
    expect(morning.toSet().difference(evening.toSet()), isNotEmpty,
        reason: 'evening looks like a copy of morning — the split failed');
  });

  test('run-on adhkar are broken into lines at their seams', () {

    final morning = adhkarSets['morning']!;

    // The isti'adha introduces what follows it, so it gets its own line.
    final kursi = morning.firstWhere((d) => bare(d.text).contains('اعوذ بالله من الشيطان'));
    expect(kursi.text, contains('\n'));
    expect(bare(kursi.text.split('\n').first), 'اعوذ بالله من الشيطان الرجيم');

    // The three mu'awwidhat are recited as three units; each sura and its
    // bismillah start a line, so the entry is six lines, not one block.
    final muawwidhat = morning.firstWhere((d) => bare(d.text).contains('قل هو الله احد'));
    final lines = muawwidhat.text.split('\n');
    expect(lines.length, 6);
    expect(bare(lines[0]), 'بسم الله الرحمن الرحيم');
    expect(bare(lines[1]), startsWith('قل هو الله احد'));
    expect(bare(lines[3]), startsWith('قل اعوذ برب الفلق'));
    expect(bare(lines[5]), startsWith('قل اعوذ برب الناس'));
  });
}

/// The book's own English rendering, carried alongside every dhikr.
///
/// Aligned in the generator by the source's own ID. If that alignment ever
/// slips — the editions falling out of step, a chapter changing shape — the
/// symptom is silent: some adhkar quietly lose their translation, or worse,
/// pick up the neighbouring one. An empty translation is the detectable half,
/// so this is what guards it.
///
/// Two evening entries are a deliberate exception: for حصن المسلم IDs 81 and
/// 90 the publisher's English edition gives only an Arabic-transliteration
/// note ("read amsayna instead of asbahna") and no English evening sentence.
/// Rather than compose one, those evening entries carry no English at all —
/// their Arabic (correctly substituted) still shows. This test pins that
/// down: if either ever becomes non-empty the source has changed and the
/// generator should be picking the new wording up; if any *other* entry goes
/// empty the ID alignment has slipped.
void _translationChecks() {
  final noEnglishEvening = {
    'امسينا علي فطره الاسلام', // ID 90 — أمسينا على فطرة الإسلام
    'اللهم ما امسي بي من نعمه', // ID 81 — اللهم ما أمسى بي من نعمة
  };
  bool isKnownEmpty(String text) =>
      noEnglishEvening.any((p) => bare(text).startsWith(p));

  test('every dhikr carries the book\'s English rendering', () {
    adhkarSets.forEach((key, items) {
      for (var i = 0; i < items.length; i++) {
        if (isKnownEmpty(items[i].text)) {
          expect(items[i].translation.trim(), isEmpty,
              reason: '$key[$i]: the English edition now has an evening '
                  'rendering for this one — update tool/generate_adhkar.py');
          continue;
        }
        expect(items[i].translation.trim(), isNotEmpty,
            reason: '$key[$i] lost its translation — check the ID alignment '
                'in tool/generate_adhkar.py');
      }
    });
  });

  test('a translation is never the Arabic text over again', () {
    for (final items in adhkarSets.values) {
      for (final item in items) {
        expect(item.translation, isNot(item.text));
      }
    }
  });
}


/// Guards against shipping a dhikr that stops in the middle.
///
/// The book gives the evening wording as an insert — "[وإذا أمسى قال: …]" —
/// that replaces part of a dhikr rather than all of it. An earlier generator
/// took that insert as the whole evening text, and six adhkar shipped
/// truncated; one of them ended on "اللهم ما أمسى بي...", eighteen
/// characters long. Nothing in the app could notice: a short string renders
/// perfectly happily.
///
/// The two guards below are what notice. The shortest legitimate dhikr in
/// the book is 30 characters; every fragment the bug produced was 24 or
/// fewer, so the threshold sits in the gap between them.
void _completenessChecks() {
  test('no dhikr is left hanging on an ellipsis', () {
    adhkarSets.forEach((key, items) {
      for (var i = 0; i < items.length; i++) {
        final text = items[i].text.trimRight();
        expect(text.endsWith('...') || text.endsWith('\u2026'), isFalse,
            reason: '$key[$i] ends mid-sentence — the evening insert was '
                'taken for the whole dhikr again');
      }
    });
  });

  test('no dhikr is shorter than the shortest real one', () {
    adhkarSets.forEach((key, items) {
      for (var i = 0; i < items.length; i++) {
        expect(items[i].text.trim().length, greaterThanOrEqualTo(28),
            reason: '$key[$i] is too short to be a whole dhikr');
      }
    });
  });

  test('the evening wording is the evening wording, not the morning\'s', () {
    // The book states the change inline ("وإذا أمسى قال: …"); the generator
    // applies it, so the evening entries read أَمْسَيْنَا / أَمْسَى, never
    // أَصْبَحْنَا / أَصْبَحْتُ. A regression here means the substitution
    // silently stopped firing.
    String bare(String s) =>
        s.replaceAll(RegExp('[\u064B-\u0652\u0670\u0640]'), '');
    final morningStarts = {
      'اصبحنا واصبح الملك لله',
      'اللهم بك اصبحنا، وبك امسينا',
      'اللهم اني اصبحت اشهدك',
      'اللهم ما اصبح بي من نعمة',
      'اصبحنا على فطرة الاسلام',
    };
    for (final d in adhkarSets['evening']!) {
      final b = bare(d.text).replaceAll(RegExp('[أإآ]'), 'ا');
      for (final start in morningStarts) {
        expect(b.contains(start), isFalse,
            reason: 'an evening dhikr still opens with the morning wording: '
                '"${d.text}"');
      }
    }
  });

  test('the ten-count "لا إله إلا الله وحده" is not in the morning list', () {
    // Removed on purpose: the list already carries the same dhikr once at a
    // hundred, and the two together only read as a duplicate.
    String bare(String s) =>
        s.replaceAll(RegExp('[\u064B-\u0652\u0670\u0640]'), '');
    final tens = adhkarSets['morning']!.where((d) =>
        d.count == 10 && bare(d.text).contains('لا اله الا الله وحده لا شريك له'));
    expect(tens, isEmpty);
  });
}
