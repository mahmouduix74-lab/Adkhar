import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as q;
import 'quran_reference.dart';

/// A single ayah reference — the pair that identifies any verse.
class AyahRef {
  final int surah;
  final int ayah;
  const AyahRef(this.surah, this.ayah);

  String get key => '$surah:$ayah';

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  static AyahRef? parse(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
    return (a == null || b == null) ? null : AyahRef(a, b);
  }
}

class SurahInfo {
  final int number;
  final String name;
  final int ayahCount;
  const SurahInfo(this.number, this.name, this.ayahCount);
}

/// One search hit — an ayah whose text matched.
class SearchHit {
  final AyahRef ref;
  final String surahName;
  final String text;
  const SearchHit(this.ref, this.surahName, this.text);
}

/// Where the text comes from: the `quran` package on pub.dev, which ships
/// an Uthmani rendering but states no provenance of its own. Its words were
/// compared against Tanzil's `quran-uthmani` over eight surahs (604 ayat):
/// every word matches, and the differences are all in how the marks are
/// written — the small-high-khah sukun and the KFGQPC tanween forms rather
/// than Tanzil's. The juz, hizb and page boundaries do NOT come from this
/// package (its juz table disagrees with Tanzil at juz 11); they come from
/// quran_reference.dart, generated from Tanzil.
///
/// Offline Quran access. The full Uthmani text, surah metadata and juz
/// boundaries all ship inside the `quran` package, so nothing here needs a
/// network connection. Only [tafsir] and [audioUrl] reach the internet, and
/// both are optional extras layered on top of the offline text.
class QuranRepo {
  static const int surahCount = 114;
  static const int juzCount = 30;
  static const int hizbCount = 60;

  static String surahName(int surah) => q.getSurahNameArabic(surah);
  static int ayahCount(int surah) => q.getVerseCount(surah);
  static String verse(int surah, int ayah) => q.getVerse(surah, ayah);
  /// Juz containing an ayah, from [juzStarts] — deliberately *not* the
  /// `quran` package's own table, which disagrees with Tanzil at juz 11.
  static int juzOf(int surah, int ayah) {
    var best = 1;
    for (var j = 0; j < juzStarts.length; j++) {
      final s = juzStarts[j][0], a = juzStarts[j][1];
      if (s < surah || (s == surah && a <= ayah)) {
        best = j + 1;
      } else {
        break;
      }
    }
    return best;
  }

  /// Al-Fatiha counts the basmala as ayah 1; At-Tawbah has none. Every other
  /// surah gets it rendered as a banner above the text.
  static bool showsBasmala(int surah) => surah != 1 && surah != 9;

  static List<SurahInfo> get allSurahs => List.generate(
        surahCount,
        (i) => SurahInfo(i + 1, q.getSurahNameArabic(i + 1), q.getVerseCount(i + 1)),
      );

  // -------------------------------------------------------------------
  // Boundaries — all from quran_reference.dart (Tanzil), never from the
  // `quran` package's own juz table, so juz/hizb/page agree with each other.
  // -------------------------------------------------------------------

  static const int pageCount = 604;

  static AyahRef juzStart(int juzNumber) =>
      AyahRef(juzStarts[juzNumber - 1][0], juzStarts[juzNumber - 1][1]);

  static AyahRef pageStart(int page) =>
      AyahRef(pageStarts[page - 1][0], pageStarts[page - 1][1]);

  /// Last ayah of [juzNumber] — the one before the next juz opens.
  static AyahRef juzEnd(int juzNumber) => juzNumber == juzCount
      ? const AyahRef(114, 6)
      : _previous(juzStart(juzNumber + 1))!;

  /// Surah numbers appearing anywhere inside [juzNumber], in order.
  static List<int> surahsInJuz(int juzNumber) {
    final start = juzStart(juzNumber), end = juzEnd(juzNumber);
    return [for (var s = start.surah; s <= end.surah; s++) s];
  }

  /// The [first, last] ayah range that [juzNumber] covers inside [surah].
  static List<int> juzRangeInSurah(int juzNumber, int surah) {
    final start = juzStart(juzNumber), end = juzEnd(juzNumber);
    final first = surah == start.surah ? start.ayah : 1;
    final last = surah == end.surah ? end.ayah : ayahCount(surah);
    return [first, last];
  }

  /// The ayah just before [ref] in mushaf order, or null at 1:1.
  static AyahRef? _previous(AyahRef ref) {
    if (ref.ayah > 1) return AyahRef(ref.surah, ref.ayah - 1);
    if (ref.surah == 1) return null;
    return AyahRef(ref.surah - 1, ayahCount(ref.surah - 1));
  }

  /// Every ayah on mushaf [page], in order.
  static List<AyahRef> ayatOnPage(int page) {
    final start = pageStart(page);
    final end = page < pageCount ? _previous(pageStart(page + 1))! : const AyahRef(114, 6);
    final out = <AyahRef>[];
    var surah = start.surah, ayah = start.ayah;
    while (surah < end.surah || (surah == end.surah && ayah <= end.ayah)) {
      out.add(AyahRef(surah, ayah));
      if (ayah < ayahCount(surah)) {
        ayah++;
      } else {
        surah++;
        ayah = 1;
      }
    }
    return out;
  }

  /// Which page an ayah sits on — binary search over [pageStarts].
  static int pageOfAyah(AyahRef ref) {
    var lo = 1, hi = pageCount, best = 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final s = pageStart(mid);
      final before = s.surah < ref.surah || (s.surah == ref.surah && s.ayah <= ref.ayah);
      if (before) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best;
  }

  /// Surah numbers appearing on [page], in order.
  static List<int> surahsOnPage(int page) {
    final seen = <int>[];
    for (final ref in ayatOnPage(page)) {
      if (seen.isEmpty || seen.last != ref.surah) seen.add(ref.surah);
    }
    return seen;
  }

  /// Which juz [page] falls in.
  static int juzOfPage(int page) {
    final start = pageStart(page);
    return juzOf(start.surah, start.ayah);
  }

  // ---------------------------------------------------------------------
  // Ahzab
  // ---------------------------------------------------------------------

  static AyahRef hizbStart(int hizb) =>
      AyahRef(hizbStarts[hizb - 1][0], hizbStarts[hizb - 1][1]);

  /// The two ahzab that make up [juzNumber], in order.
  static List<int> hizbsOfJuz(int juzNumber) => [juzNumber * 2 - 1, juzNumber * 2];

  /// Which hizb [page] falls in — the same walk as [juzOf], over
  /// [hizbStarts]. Shown in the page footer next to the page number.
  static int hizbOfPage(int page) {
    final start = pageStart(page);
    var best = 1;
    for (var h = 0; h < hizbStarts.length; h++) {
      final hs = hizbStarts[h][0], ha = hizbStarts[h][1];
      if (hs < start.surah || (hs == start.surah && ha <= start.ayah)) {
        best = h + 1;
      } else {
        break;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------

  static final _marks = RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  /// Diacritic-insensitive form used only for matching, never for display —
  /// so a user typing plain "العالمين" still finds "ٱلۡعَٰلَمِينَ".
  ///
  /// The dagger alef (U+0670) has to become a real alef *before* the other
  /// marks are stripped. Uthmani script writes "العالمين" with it in place
  /// of the alef, so deleting it leaves "العلمين" and the obvious query
  /// silently matches nothing.
  static String normalize(String s) => s
      .replaceAll('ٰ', 'ا')
      .replaceAll(_marks, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Surahs whose name matches [query].
  static List<SurahInfo> searchSurahs(String query) {
    final needle = normalize(query);
    if (needle.isEmpty) return const [];
    return allSurahs.where((s) => normalize(s.name).contains(needle)).toList();
  }

  /// Ayat containing [query]. Capped at [limit] — a bare word like "الله"
  /// otherwise matches thousands of verses and janks the list.
  static List<SearchHit> searchAyat(String query, {int limit = 60}) {
    final needle = normalize(query);
    if (needle.length < 2) return const [];
    final hits = <SearchHit>[];
    for (var s = 1; s <= surahCount; s++) {
      final count = ayahCount(s);
      for (var a = 1; a <= count; a++) {
        final text = verse(s, a);
        if (normalize(text).contains(needle)) {
          hits.add(SearchHit(AyahRef(s, a), surahName(s), text));
          if (hits.length >= limit) return hits;
        }
      }
    }
    return hits;
  }

  // ---------------------------------------------------------------------
  // Online extras
  // ---------------------------------------------------------------------

  static final Map<String, String> _tafsirCache = {};
  static final Map<String, String> _translationCache = {};

  /// One ayah of a translation of the Quran's meanings, from the quran.com
  /// API. Throws on failure so the caller can offer a retry.
  ///
  /// The cache is deliberately in memory only, and this is a licence
  /// condition rather than a preference: the Quran Foundation developer
  /// terms forbid caching or storing their content for longer than one
  /// week. A Map on the heap dies with the process, so it cannot outlive
  /// that no matter how long the app is left running. Do not "improve" this
  /// into shared_preferences or a file — that would put us in breach.
  static Future<String> translation(AyahRef ref, int editionId) async {
    final key = '$editionId:${ref.key}';
    final cached = _translationCache[key];
    if (cached != null) return cached;

    final url = 'https://api.quran.com/api/v4/quran/translations/$editionId'
        '?verse_key=${ref.surah}:${ref.ayah}';
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('translation ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = body['translations'] as List;
    if (list.isEmpty) throw Exception('translation empty');
    // The API marks footnotes up with <sup> tags; they reference notes the
    // app has no room to show, so the markup goes rather than being printed
    // as literal angle brackets in the middle of a sentence.
    final text = (list.first as Map)['text'] as String;
    final clean = text
        .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    _translationCache[key] = clean;
    return clean;
  }


  /// Tafsir al-Muyassar for one ayah. Online — the text is far too large to
  /// bundle. Throws on failure so the caller can show a retry.
  static Future<String> tafsir(AyahRef ref) async {
    final cached = _tafsirCache[ref.key];
    if (cached != null) return cached;

    final url = 'https://api.alquran.cloud/v1/ayah/${ref.surah}:${ref.ayah}/ar.muyassar';
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('تعذّر تحميل التفسير (رمز ${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final text = ((body['data'] as Map)['text'] as String).trim();
    _tafsirCache[ref.key] = text;
    return text;
  }

  /// Streaming URL for a recitation of one ayah (Mishary Alafasy). Online.
  static String audioUrl(AyahRef ref) => q.getAudioURLByVerse(ref.surah, ref.ayah);
}
