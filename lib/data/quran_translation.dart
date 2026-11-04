/// Which translation of the Quran's meanings the app shows, per interface
/// language.
///
/// Source of every entry: the quran.com translation catalogue
/// (https://api.quran.com/api/v4/resources/translations), read September
/// 2026. The ids below were taken from that catalogue, not written from
/// memory, and each one was checked to return text for 2:255 before it was
/// listed here.
///
/// Chosen for institutional authority wherever an official body publishes
/// one. Five of the nine are the King Fahd Glorious Quran Printing Complex's
/// own translation or a national religious authority's:
///
///   fr  Hamidullah          — the Complex's French edition
///   de  Bubenheim & Elyas   — the Complex's German edition
///   ru  Kuliev              — the Complex's Russian edition
///   ur  Junagarhi           — the Complex's Urdu edition
///   id  King Fahd Complex   — published under the Complex's own name
///   tr  Diyanet İşleri      — the Turkish state religious authority
///   ms  Basmeih             — the official Malaysian translation
///
/// English and Spanish have no single official edition. English is Saheeh
/// International, the most widely used contemporary rendering; the Complex's
/// own English (Hilali & Khan, id 203) is available and can be swapped in
/// here if that is preferred. Spanish is Isa García, published by Noor
/// International.
///
/// NOTHING HERE IS BUNDLED, and that is a licence requirement rather than a
/// precaution. The Quran Foundation developer terms permit showing this
/// content inside an app — including an app that charges, carries ads or
/// takes donations — but forbid redistributing it "as a dataset, data feed,
/// API, content package, or other separately distributed product". A
/// generated Dart file of translation text shipped in the binary is exactly
/// that. So the text is fetched from the publisher's API on demand and held
/// in memory only, the same way the tafsir is.
///
/// Terms read September 2026:
/// https://api-docs.quran.foundation/legal/developer-terms/
///
/// Arabic is absent on purpose, and that is not an oversight: the Arabic is
/// the Quran, and there is nothing for an Arabic reader to translate it
/// into. What the app shows in other languages is a translation of the
/// *meanings* — one person's understanding, not the revealed text — which is
/// why it is labelled that way on screen and always carries its translator's
/// name.
class QuranTranslation {
  /// quran.com edition id.
  final int editionId;

  /// Shown on screen with the text. A translation of scripture without its
  /// translator's name is an anonymous claim about what God said.
  final String translator;

  const QuranTranslation(this.editionId, this.translator);

  static const Map<String, QuranTranslation> _byLanguage = {
    'en': QuranTranslation(20, 'Saheeh International'),
    'fr': QuranTranslation(31, 'Muhammad Hamidullah'),
    'tr': QuranTranslation(77, 'Diyanet İşleri'),
    'id': QuranTranslation(134, 'King Fahd Quran Complex'),
    'ur': QuranTranslation(54, 'محمد جوناگڑھی'),
    'es': QuranTranslation(83, 'Isa García'),
    'de': QuranTranslation(27, 'Bubenheim & Elyas'),
    'ms': QuranTranslation(39, 'Abdullah Muhammad Basmeih'),
    'ru': QuranTranslation(45, 'Эльмир Кулиев'),
  };

  /// The translation to show for [languageCode], or null when there is none
  /// to show — which is the correct answer for Arabic.
  static QuranTranslation? forLanguage(String languageCode) =>
      _byLanguage[languageCode];

  /// Every language the app can show a translation in.
  static Iterable<String> get languages => _byLanguage.keys;
}
