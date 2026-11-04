import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/quran_repository.dart';

void main() {
  group('offline text', () {
    test('reads the whole mushaf without a network', () {
      expect(QuranRepo.surahName(1), contains('فاتحة'));
      expect(QuranRepo.ayahCount(2), 286);
      expect(QuranRepo.ayahCount(114), 6);
      expect(QuranRepo.verse(112, 1), isNotEmpty);
      // Every surah is readable end to end.
      for (var s = 1; s <= QuranRepo.surahCount; s++) {
        expect(QuranRepo.verse(s, QuranRepo.ayahCount(s)), isNotEmpty,
            reason: 'last ayah of surah $s is empty');
      }
    });

    test('basmala is a banner everywhere except Al-Fatiha and At-Tawbah', () {
      expect(QuranRepo.showsBasmala(1), isFalse);
      expect(QuranRepo.showsBasmala(9), isFalse);
      expect(QuranRepo.showsBasmala(2), isTrue);
      expect(QuranRepo.showsBasmala(114), isTrue);
    });
  });

  group('ahzab table', () {
    test('every hizb starts at a real ayah', () {
      for (var h = 1; h <= QuranRepo.hizbCount; h++) {
        final start = QuranRepo.hizbStart(h);
        expect(start.surah, inInclusiveRange(1, QuranRepo.surahCount),
            reason: 'hizb $h has an out-of-range surah');
        expect(start.ayah, inInclusiveRange(1, QuranRepo.ayahCount(start.surah)),
            reason: 'hizb $h starts past the end of surah ${start.surah}');
      }
    });

    test('ahzab run forward and never repeat', () {
      var previous = const AyahRef(0, 0);
      for (var h = 1; h <= QuranRepo.hizbCount; h++) {
        final start = QuranRepo.hizbStart(h);
        final movedOn = start.surah > previous.surah ||
            (start.surah == previous.surah && start.ayah > previous.ayah);
        expect(movedOn, isTrue, reason: 'hizb $h does not come after hizb ${h - 1}');
        previous = start;
      }
    });

    test('odd ahzab open their juz', () {
      // Both tables now come from the same Tanzil metadata, so this holds
      // exactly. It did not when the hizb list was written from memory.
      for (var juz = 1; juz <= QuranRepo.juzCount; juz++) {
        final hizb = QuranRepo.hizbsOfJuz(juz).first;
        expect(QuranRepo.hizbStart(hizb), QuranRepo.juzStart(juz),
            reason: 'hizb $hizb should start exactly where juz $juz does');
      }
    });

    test('known ahzab match the printed mushaf', () {
      // Spot-checks on the four entries that were wrong when transcribed
      // from memory, plus the anchors at each end.
      expect(QuranRepo.hizbStart(1), const AyahRef(1, 1));
      expect(QuranRepo.hizbStart(12), const AyahRef(5, 27));
      expect(QuranRepo.hizbStart(18), const AyahRef(7, 171));
      expect(QuranRepo.hizbStart(21), const AyahRef(9, 93));
      expect(QuranRepo.hizbStart(46), const AyahRef(37, 145));
      expect(QuranRepo.hizbStart(60), const AyahRef(87, 1));
    });
  });

  group('search', () {
    // Regression: the diacritic class was written with literal characters,
    // which parsed as U+061A-U+0670 and matched every Arabic *letter*.
    // normalize() returned '' and every query "matched" because empty
    // contains empty — so asserting on matches alone proved nothing. These
    // assert the normalized value itself.
    test('normalize strips marks and keeps letters', () {
      expect(QuranRepo.normalize('ٱلۡحَمۡدُ لِلَّهِ'), 'الحمد لله');
      expect(QuranRepo.normalize('ٱلۡعَٰلَمِينَ'), 'العالمين');
      expect(QuranRepo.normalize('حَسْبِيَ اللَّهُ'), 'حسبي الله');
      expect(QuranRepo.normalize('بِسْمِ'), isNotEmpty);
    });

    test('search does not match unrelated text', () {
      // With a broken normalize this returned hits for anything.
      expect(QuranRepo.searchSurahs('زقزقة'), isEmpty);
      expect(QuranRepo.searchAyat('زقزقة الطيور'), isEmpty);
    });

    test('finds a surah by name', () {
      final hits = QuranRepo.searchSurahs('البقرة');
      expect(hits.map((s) => s.number), contains(2));
    });

    test('matches ayat regardless of diacritics', () {
      // Typed bare, the way a user would; the mushaf text is fully voweled.
      final hits = QuranRepo.searchAyat('الحمد لله رب العالمين');
      expect(hits, isNotEmpty);
      expect(hits.first.ref, const AyahRef(1, 2));
    });

    test('ignores queries too short to be useful', () {
      expect(QuranRepo.searchAyat('ا'), isEmpty);
    });

    test('caps the result count', () {
      final hits = QuranRepo.searchAyat('الله', limit: 25);
      expect(hits.length, 25);
    });
  });

  group('pages', () {
    test('there are 604 of them, in order, covering the whole mushaf', () {
      expect(QuranRepo.pageStart(1), const AyahRef(1, 1));
      expect(QuranRepo.pageStart(2), const AyahRef(2, 1));
      expect(QuranRepo.pageStart(QuranRepo.pageCount), const AyahRef(112, 1));

      var previous = const AyahRef(0, 0);
      for (var p = 1; p <= QuranRepo.pageCount; p++) {
        final start = QuranRepo.pageStart(p);
        final forward = start.surah > previous.surah ||
            (start.surah == previous.surah && start.ayah > previous.ayah);
        expect(forward, isTrue, reason: 'page \$p does not come after page \${p - 1}');
        previous = start;
      }
    });

    test('every ayah lands on exactly one page, and pages tile the mushaf', () {
      var total = 0;
      for (var p = 1; p <= QuranRepo.pageCount; p++) {
        final refs = QuranRepo.ayatOnPage(p);
        expect(refs, isNotEmpty, reason: 'page \$p is empty');
        expect(QuranRepo.pageOfAyah(refs.first), p);
        expect(QuranRepo.pageOfAyah(refs.last), p);
        total += refs.length;
      }
      // 6236 is the ayah count of the Uthmani mushaf.
      expect(total, 6236);
    });

    test('juz of a page agrees with the juz of its first ayah', () {
      for (var juz = 1; juz <= QuranRepo.juzCount; juz++) {
        final start = QuranRepo.juzStart(juz);
        expect(QuranRepo.juzOf(start.surah, start.ayah), juz);
      }
    });
  });
}
