import 'package:flutter/material.dart';

import '../theme.dart';

/// Whether numbers should render in Arabic-Indic digits.
///
/// Set once per build in MaterialApp's `builder`, next to the palette —
/// true for Arabic and Urdu, false for the Latin-script locales, where
/// "٦:٣٥" reads as broken text rather than a time.
bool useArabicDigits = true;

/// Renders any number/numeric string in Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩)
/// when the active locale calls for them, and leaves it alone otherwise.
String ar(Object n) {
  if (!useArabicDigits) return n.toString();
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) {
    final i = western.indexOf(c);
    return i == -1 ? c : eastern[i];
  }).join();
}

/// 12-hour clock in Arabic-Indic digits with an ص/م marker, e.g.
/// 17:05 → "٥:٠٥ م", 05:00 → "٥:٠٠ ص".
///
/// The marker is not decoration: without it 23:09 and 11:09 both render as
/// "١١:٠٩", which in a prayer-times app is the difference between Isha and
/// mid-morning.
String formatClock(int hour24, int minute) {
  final h = hour24 % 12 == 0 ? 12 : hour24 % 12;
  // The marker follows the same script choice as the digits: "6:35 ص" in
  // an English UI is as out of place as Arabic-Indic numerals would be.
  final marker = useArabicDigits
      ? (hour24 < 12 ? 'ص' : 'م')
      : (hour24 < 12 ? 'AM' : 'PM');
  return '${ar(h)}:${ar(minute.toString().padLeft(2, '0'))} $marker';
}

/// A "done / total" counter that reads the same in every language: the
/// progress figure on the left, the target on the right, digits in the
/// interface's own numerals. Left in raw text it inherits the surrounding
/// bidi context and flips — "٥ / ٢٣" turning into "٢٣ / ٥".
Widget fractionText(int done, int total,
    {double size = 14, FontWeight weight = FontWeight.w500, Color? color}) {
  // Three separate Text widgets in an explicitly LTR Row. As one string,
  // "٥ / ٢٣" gets reordered by the bidi algorithm — the slash is a
  // separator, the digits are Arabic-Number runs, and the whole thing
  // flips to "٢٣ / ٥". Kept apart, nothing can reorder across them.
  final style = uiFont(size: size, weight: weight, color: color);
  return Row(
    mainAxisSize: MainAxisSize.min,
    textDirection: TextDirection.ltr,
    children: [
      Text(ar(done), style: style),
      Text(' / ', style: style),
      Text(ar(total), style: style),
    ],
  );
}
