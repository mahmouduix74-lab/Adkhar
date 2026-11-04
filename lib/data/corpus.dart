import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'islamic_corpus.dart';
import 'quran_repository.dart';

/// One searchable passage plus where it is from. `citation` is always shown.
class CorpusEntry {
  final String kind; // 'tafsir' | 'dua' | 'hadith'
  final String text;
  final String citation;
  const CorpusEntry(this.kind, this.text, this.citation);
}

/// The offline reference the assistant reads on top of the Quran text:
/// التفسير الميسّر (every ayah), the whole of حصن المسلم (every chapter), and
/// الأربعون النووية. Bundled as assets, parsed once on first use.
class Corpus {
  Corpus._();
  static final instance = Corpus._();

  bool _loaded = false;

  /// ayah "s:a" -> tafsir text
  final Map<String, String> tafsir = {};

  /// every du'a in the book, with its chapter title
  final List<CorpusEntry> dua = [];

  /// the 42 hadith of an-Nawawi
  final List<CorpusEntry> hadith = [];

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    final tafsirRaw = await rootBundle.loadString('assets/corpus/tafsir_muyassar.json');
    (jsonDecode(tafsirRaw) as Map<String, dynamic>)
        .forEach((k, v) => tafsir[k] = v as String);

    final hisnRaw = await rootBundle.loadString('assets/corpus/hisn_full.json');
    for (final ch in jsonDecode(hisnRaw) as List) {
      final title = (ch['title'] as String).trim();
      for (final item in ch['items'] as List) {
        final text = _stripEdges(item['text'] as String);
        final n = item['repeat'] as int;
        dua.add(CorpusEntry(
          'dua',
          text,
          'حصن المسلم · $title${n > 1 ? ' · تُقال $n مرات' : ''}',
        ));
      }
    }

    for (final h in nawawiForty) {
      hadith.add(CorpusEntry(
        'hadith',
        h.text,
        'الأربعون النووية · الحديث ${h.number}',
      ));
    }
  }

  /// The book wraps some du'a in ( … ) or trailing repetition notes; the
  /// text search does not need them.
  static String _stripEdges(String s) => s
      .replaceAll(RegExp(r'^[\(\s]+|[\)\s]+$'), '')
      .replaceAll(RegExp(r'\s*\([^()]*مرات?[^()]*\)\s*$'), '')
      .trim();

  /// Tafsir for [ref], or null if the corpus is not loaded / no entry.
  String? tafsirFor(AyahRef ref) => tafsir['${ref.surah}:${ref.ayah}'];
}
