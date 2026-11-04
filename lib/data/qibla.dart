import 'dart:math' as math;

/// The direction of the Kaaba from anywhere on earth.
///
/// Source of the constants and of the reference bearings in
/// `test/qibla_test.dart`: the AlAdhan qibla service
/// (https://api.aladhan.com/v1/qibla/{lat}/{lng}), queried September 2026.
/// The coordinates below were not taken from memory — they were confirmed
/// against that service by probing along the Kaaba's own meridian, where
/// the reported bearing flips from ~0° to ~180° exactly between latitude
/// 21.4225 and 21.4226, and a due-north point on longitude 39.8262 reports
/// 180.0002°.
///
/// The bearing is the initial heading of the great circle to Mecca — the
/// shortest path over the sphere, which is the method used by the prayer
/// authorities and by every qibla service worth checking against. It is not
/// the constant compass heading (rhumb line), which drifts further from the
/// true direction the further you are from Mecca.
class Qibla {
  const Qibla._();

  static const double kaabaLat = 21.4225;
  static const double kaabaLng = 39.8262;

  /// Degrees clockwise from true north, in [0, 360).
  static double bearingFrom(double lat, double lng) {
    const rad = math.pi / 180;
    final phi1 = lat * rad;
    final phi2 = kaabaLat * rad;
    final dLambda = (kaabaLng - lng) * rad;

    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);

    final deg = math.atan2(y, x) / rad;
    return (deg + 360) % 360;
  }

  /// Great-circle distance to the Kaaba in kilometres, on a mean-radius
  /// sphere. Shown alongside the dial so a reading that is wildly wrong has
  /// something to be wrong against.
  static double distanceKmFrom(double lat, double lng) {
    const rad = math.pi / 180;
    const earthRadiusKm = 6371.0088; // IUGG mean radius
    final phi1 = lat * rad;
    final phi2 = kaabaLat * rad;
    final dPhi = (kaabaLat - lat) * rad;
    final dLambda = (kaabaLng - lng) * rad;

    final a = math.pow(math.sin(dPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
