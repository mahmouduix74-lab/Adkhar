import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:adhkar_app/data/qibla.dart';

/// The expected bearings are not written from memory: each was read from the
/// AlAdhan qibla service (https://api.aladhan.com/v1/qibla/{lat}/{lng}) in
/// September 2026 and is reproduced here with the coordinates it was asked
/// about, so the check can be repeated against the same source.
const _published = <String, List<double>>{
  //          latitude,   longitude,  bearing°
  'Cairo': [30.0444, 31.2357, 136.137],
  'Istanbul': [41.0082, 28.9784, 151.621],
  'Jakarta': [-6.2088, 106.8456, 295.152],
  'New York': [40.7128, -74.0060, 58.482],
  'London': [51.5074, -0.1278, 118.987],
  'Sydney': [-33.8688, 151.2093, 277.500],
};

void main() {
  group('bearing matches the published qibla for', () {
    _published.forEach((city, v) {
      test(city, () {
        expect(Qibla.bearingFrom(v[0], v[1]), closeTo(v[2], 0.01));
      });
    });
  });

  test('due north of the Kaaba points south, due south points north', () {
    expect(Qibla.bearingFrom(Qibla.kaabaLat + 10, Qibla.kaabaLng),
        closeTo(180, 0.001));
    expect(Qibla.bearingFrom(Qibla.kaabaLat - 10, Qibla.kaabaLng) % 360,
        closeTo(0, 0.001));
  });

  test('mirrored longitudes give mirrored bearings', () {
    final east = Qibla.bearingFrom(30, Qibla.kaabaLng + 20);
    final west = Qibla.bearingFrom(30, Qibla.kaabaLng - 20);
    expect(east + west, closeTo(360, 0.001));
  });

  test('always returns a heading inside one turn', () {
    final rnd = math.Random(7);
    for (var i = 0; i < 500; i++) {
      final lat = rnd.nextDouble() * 180 - 90;
      final lng = rnd.nextDouble() * 360 - 180;
      final b = Qibla.bearingFrom(lat, lng);
      expect(b, inInclusiveRange(0, 360));
      expect(b.isNaN, isFalse);
    }
  });

  test('distance to the Kaaba is zero at the Kaaba and sane elsewhere', () {
    expect(Qibla.distanceKmFrom(Qibla.kaabaLat, Qibla.kaabaLng),
        closeTo(0, 0.001));
    // Cairo to Mecca is a little over 1200 km on any reasonable sphere.
    expect(Qibla.distanceKmFrom(30.0444, 31.2357), inInclusiveRange(1200, 1350));
  });
}
