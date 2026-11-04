import '../data/adhkar_data.dart';
import '../models/dhikr.dart';
import 'corpus.dart';
import 'quran_repository.dart';

enum AnswerKind { ayah, dhikr, tafsir, hadith, none }

class AssistantAnswer {
  final AnswerKind kind;
  final String text;

  /// Where this came from — always shown, never omitted.
  final String citation;

  const AssistantAnswer({
    required this.kind,
    required this.text,
    required this.citation,
  });
}

/// Answers questions **only** out of the content this app ships and can
/// cite: the Uthmani mushaf, التفسير الميسّر, the whole of حصن المسلم, and
/// الأربعون النووية.
///
/// It is a retrieval engine, not a mufti. It never composes an answer of its
/// own, never rules on anything, and when it finds nothing it says so rather
/// than filling the gap. That is a deliberate limit: a wrong religious
/// answer costs more than a missing one. Everything is offline.
class Assistant {
  /// Words too common to narrow anything down. Dropped from the query so
  /// "ما هو دعاء السفر" searches for "دعاء السفر".
  static const _stopWords = {
    'ما', 'ماهو', 'ماهي', 'هو', 'هي', 'من', 'عن', 'في', 'على', 'الى', 'إلى',
    'هل', 'كيف', 'متى', 'اين', 'أين', 'ايه', 'ايه؟', 'يا', 'و', 'او', 'أو',
    'ال', 'لي', 'لك', 'ان', 'أن', 'إن', 'دعاء', 'ذكر', 'معنى', 'تفسير',
    'حديث', 'the', 'what', 'is', 'a', 'of', 'for', 'how', 'when', 'where',
    'do', 'i', 'my', 'to', 'and', 'meaning', 'dua', 'hadith',
  };

  static final _stopSet =
      _stopWords.map(QuranRepo.normalize).toSet();

  static List<String> _terms(String query) => QuranRepo.normalize(query)
      .split(' ')
      .where((w) => w.length > 1 && !_stopSet.contains(w))
      .toList();

  /// Best matches for [query], most relevant first. Empty means "I have
  /// nothing sourced for this" — the caller must not paper over that.
  static Future<List<AssistantAnswer>> answer(String query,
      {int limit = 6}) async {
    await Corpus.instance.ensureLoaded();

    final terms = _terms(query);
    if (terms.isEmpty) return const [];
    final needles = terms.map(QuranRepo.normalize).toList();
    // The whole query, normalised — an exact match on this is the strongest
    // signal there is ("إنما الأعمال بالنيات" is the hadith, not an ayah
    // that happens to mention الأعمال).
    final phrase = QuranRepo.normalize(query);
    int phraseBonus(String body) =>
        QuranRepo.normalize(body).contains(phrase) ? 12 : 0;

    final scored = <(int, AssistantAnswer)>[];

    // 1) du'a — a question phrased as "دعاء السفر" wants the supplication.
    for (final e in Corpus.instance.dua) {
      final s = _hits(e.text, e.citation, needles, titleWeight: 4) +
          phraseBonus(e.text);
      if (s > 0) {
        scored.add((s, AssistantAnswer(
            kind: AnswerKind.dhikr, text: e.text, citation: e.citation)));
      }
    }
    // the morning/evening sets carry the app's own repetition counts
    for (final meta in catalog) {
      for (final d in adhkarSets[meta.key]!) {
        final s = _score(d, meta.name, needles);
        if (s > 0) {
          scored.add((s + 1, AssistantAnswer(
              kind: AnswerKind.dhikr,
              text: d.text,
              citation: 'حصن المسلم · ${meta.name}'
                  '${d.count > 1 ? ' · تُقال ${d.count} مرات' : ''}')));
        }
      }
    }

    // 2) hadith — الأربعون النووية
    for (final e in Corpus.instance.hadith) {
      final s = _hits(e.text, '', needles) + phraseBonus(e.text);
      if (s > 0) {
        scored.add((s, AssistantAnswer(
            kind: AnswerKind.hadith, text: e.text, citation: e.citation)));
      }
    }

    // 3) the mushaf — the whole phrase first, then each term
    final ayat = <AyahRef, SearchHit>{};
    for (final hit in QuranRepo.searchAyat(needles.join(' '), limit: limit)) {
      ayat[hit.ref] = hit;
    }
    if (ayat.length < 3) {
      for (final n in needles) {
        for (final hit in QuranRepo.searchAyat(n, limit: 3)) {
          ayat.putIfAbsent(hit.ref, () => hit);
        }
      }
    }
    for (final hit in ayat.values) {
      scored.add((terms.length * 2, AssistantAnswer(
        kind: AnswerKind.ayah,
        text: hit.text,
        citation: '${hit.surahName} · آية ${hit.ref.ayah}',
      )));
      // 4) and its tafsir, for "ما معنى…" style questions
      final t = Corpus.instance.tafsirFor(hit.ref);
      if (t != null) {
        scored.add((terms.length * 2 - 1, AssistantAnswer(
          kind: AnswerKind.tafsir,
          text: t,
          citation:
              'التفسير الميسّر · ${hit.surahName} آية ${hit.ref.ayah}',
        )));
      }
    }
    // scored free-text tafsir scan — catches paraphrased "what does X mean"
    final tafsirScored = <(int, String, String)>[];
    Corpus.instance.tafsir.forEach((key, value) {
      final s = _hits(value, '', needles) + phraseBonus(value);
      if (s >= needles.length) tafsirScored.add((s, key, value));
    });
    tafsirScored.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (s, key, value) in tafsirScored.take(limit)) {
      final parts = key.split(':');
      scored.add((s + needles.length, AssistantAnswer(
        kind: AnswerKind.tafsir,
        text: value,
        citation: 'التفسير الميسّر · '
            '${QuranRepo.surahName(int.parse(parts[0]))} آية ${parts[1]}',
      )));
    }

    scored.sort((a, b) => b.$1.compareTo(a.$1));
    // de-dup on text
    final seen = <String>{};
    final out = <AssistantAnswer>[];
    for (final (_, a) in scored) {
      if (seen.add(a.text)) out.add(a);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// One point per needle found in [body], [titleWeight] per needle found in
  /// [context] (the citation string — the chapter title lives there).
  static int _hits(String body, String context, List<String> needles,
      {int titleWeight = 0}) {
    final b = QuranRepo.normalize(body);
    final c = QuranRepo.normalize(context);
    var score = 0;
    for (final n in needles) {
      if (titleWeight > 0 && c.contains(n)) score += titleWeight;
      if (b.contains(n)) score += 1;
    }
    return score;
  }

  static int _score(DhikrItem item, String categoryName, List<String> needles) {
    final body = QuranRepo.normalize(item.text);
    final category = QuranRepo.normalize(categoryName);
    var score = 0;
    for (final n in needles) {
      if (category.contains(n)) score += 3;
      if (body.contains(n)) score += 1;
    }
    return score;
  }
}
