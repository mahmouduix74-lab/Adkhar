import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/assistant.dart';

/// The assistant's contract is as much about what it *refuses* to do as
/// what it returns: it only ever hands back text the app already ships and
/// can cite (Quran, التفسير الميسّر, all of حصن المسلم, الأربعون النووية),
/// and it stays silent rather than inventing an answer. All offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds a dhikr by the category a question names', () async {
    final answers = await Assistant.answer('ما هو دعاء السفر');
    expect(answers, isNotEmpty);
    expect(answers.first.kind, AnswerKind.dhikr);
    expect(answers.first.citation, contains('حصن المسلم'));
  });

  test('finds an ayah the question quotes', () async {
    final answers = await Assistant.answer('الحمد لله رب العالمين');
    expect(answers.any((a) => a.kind == AnswerKind.ayah), isTrue);
  });

  test('reaches into the wider corpus — tafsir and the forty hadith', () async {
    final tafsir = await Assistant.answer('معنى الصمد');
    expect(tafsir.any((a) => a.kind == AnswerKind.tafsir), isTrue);

    final hadith = await Assistant.answer('إنما الأعمال بالنيات');
    expect(hadith.any((a) => a.kind == AnswerKind.hadith), isTrue,
        reason: 'the first hadith of an-Nawawi should be reachable');
  });

  test('every answer carries a citation', () async {
    for (final query in ['أذكار النوم', 'الرحمن الرحيم', 'دعاء الكرب', 'الإحسان']) {
      for (final a in await Assistant.answer(query)) {
        expect(a.citation.trim(), isNotEmpty,
            reason: 'uncited answer for "$query"');
        expect(a.text.trim(), isNotEmpty);
      }
    }
  });

  test('returns nothing rather than guessing', () async {
    expect(await Assistant.answer('زقزقة العصافير في نيوزيلندا'), isEmpty);
    expect(await Assistant.answer('bitcoin price forecast'), isEmpty);
  });

  test('ignores queries that are only filler words', () async {
    expect(await Assistant.answer('ما هو'), isEmpty);
    expect(await Assistant.answer('هل'), isEmpty);
  });
}
