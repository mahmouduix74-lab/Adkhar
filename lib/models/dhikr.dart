/// A single dhikr entry: its Arabic text, an optional short note
/// (e.g. the surah name, or "بعد السلام"), and how many times it is
/// repeated. [count] is the *target* repeat count; how many the user
/// has completed so far lives in AppState, not here — this class is
/// pure content, never mutated at runtime.
class DhikrItem {
  final String text;
  final String note;
  final int count;

  /// The book's own English rendering, empty when the source has none.
  ///
  /// English only, and that is not laziness: hisnmuslim.com publishes the
  /// book in Arabic and English, and nothing else. Translating a du'a into
  /// the app's other seven languages would mean inventing religious text,
  /// which is not something this app does — every word in it traces to a
  /// publisher.
  final String translation;

  const DhikrItem({
    required this.text,
    this.note = '',
    required this.count,
    this.translation = '',
  });
}
