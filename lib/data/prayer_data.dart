// `adhan` exports its own Prayer enum; ours is the richer UI model.
import 'package:adhan/adhan.dart' hide Prayer;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/prayer.dart';

/// Sky palette for one period of the day. Each of the six windows gets its
/// own gradient so the header colour tells you the time of day at a glance.
class _Sky {
  final Color c1, c2, c3;
  const _Sky(this.c1, this.c2, this.c3);
}

/// Keyed by the period a time falls *into*, not by the adhan that opens it:
/// "الضحى" is the stretch between sunrise and Dhuhr, and it gets the bright
/// morning sky rather than sunrise's orange.
///
/// Every gradient here is deep enough to carry white text at every stop.
/// The daytime skies used to be pale, which forced the header to flip to
/// dark type around noon — the header now reads the same all day, in every
/// theme, and [_Sky.light] is false throughout because of it.
const Map<String, _Sky> _skies = {
  // Six visibly distinct skies. They all have to be deep enough for white
  // text, which is what collapsed them last time: deepening الضحى and الظهر
  // separately landed them within two hex points of each other, so crossing
  // from one into the other changed nothing on screen. Each window now moves
  // along the hue as well as the value — indigo, blue, teal, bronze, wine,
  // black — so the change is obvious even at a glance.
  'الفجر': _Sky(Color(0xFF0B1026), Color(0xFF2E2F6B), Color(0xFF5B4E92)),
  'الضحى': _Sky(Color(0xFF0A4C6B), Color(0xFF1B87A8), Color(0xFF4FB3C4)),
  // Noon is the sun at its highest: a deep, saturated cobalt with glare in
  // it. It was teal first, which read as the wrong hour, then amber — but an
  // orange sky means the sun is *setting*, so it collided with Maghrib. The
  // heat of midday shows as brightness, not as warm hue.
  'الظهر': _Sky(Color(0xFF0E3D8C), Color(0xFF2C6FD1), Color(0xFF7FA8DC)),
  'العصر': _Sky(Color(0xFF23374D), Color(0xFF6B6A72), Color(0xFFB08D57)),
  'المغرب': _Sky(Color(0xFF2A1436), Color(0xFF8C3F57), Color(0xFFC26C42)),
  'العشاء': _Sky(Color(0xFF05070F), Color(0xFF141F3D), Color(0xFF3A4463)),
};

const _Sky _fallbackSky = _Sky(Color(0xFF0B1026), Color(0xFF2A3566), Color(0xFF7D7FA8));

/// Cairo, Egypt — used until (or unless) the device gives us real
/// coordinates, so the app always has a sane schedule to show.
final _defaultCoordinates = Coordinates(30.0444, 31.2357);

/// A day's schedule of the six windows the UI paints, in order.
///
/// Note these are *periods*, not just adhan times: "الضحى" starts at sunrise
/// and is what the header shows all morning. That is why this list is built
/// here rather than handed straight out of the `adhan` package.
List<Prayer> buildSchedule(PrayerTimes times) {
  Prayer at(String name, DateTime t) {
    final sky = _skies[name] ?? _fallbackSky;
    return Prayer(
      name: name,
      minutes: t.hour * 60 + t.minute,
      c1: sky.c1,
      c2: sky.c2,
      c3: sky.c3,
      light: false,
    );
  }

  return [
    at('الفجر', times.fajr),
    at('الضحى', times.sunrise),
    at('الظهر', times.dhuhr),
    at('العصر', times.asr),
    at('المغرب', times.maghrib),
    at('العشاء', times.isha),
  ];
}

/// Prayer times for [date] at [coordinates], Egyptian General Authority
/// method (the common one for Egypt and much of North Africa).
PrayerTimes computeTimes(Coordinates coordinates, DateTime date) {
  final params = CalculationMethod.egyptian.getParameters()..madhab = Madhab.shafi;
  return PrayerTimes(coordinates, DateComponents.from(date), params);
}

/// The device's coordinates, or null if location is unavailable or the user
/// declined. Callers fall back to [_defaultCoordinates] — the app must never
/// block on this.
Future<Coordinates?> deviceCoordinates() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 10));
    return Coordinates(pos.latitude, pos.longitude);
  } catch (_) {
    return null; // any failure just means "use the fallback city"
  }
}

Coordinates get fallbackCoordinates => _defaultCoordinates;

/// The window we're currently inside: the last one that has already started,
/// wrapping back to Isha (yesterday's) before Fajr.
Prayer currentPrayer(List<Prayer> schedule, int nowMin) {
  Prayer current = schedule.last;
  for (final p in schedule) {
    if (nowMin >= p.minutes) current = p;
  }
  return current;
}

Prayer nextPrayer(List<Prayer> schedule, int nowMin) {
  for (final p in schedule) {
    if (p.minutes > nowMin) return p;
  }
  return schedule.first; // wraps to tomorrow's Fajr
}
