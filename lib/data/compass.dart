import 'package:flutter/services.dart';

/// The device's heading, in degrees clockwise from north.
///
/// Backed by a channel implemented in the app itself — CoreLocation on iOS,
/// the rotation-vector sensor on Android — rather than by a plugin. Every
/// other dependency here resolves through Swift Package Manager, and the
/// compass plugins on pub are CocoaPods-only; taking one would have made a
/// `pod install` a prerequisite of every iOS build for one number.
///
/// The stream simply ends when the device has no magnetometer, which the
/// qibla screen treats as "show the bearing, lock the dial".
class DeviceCompass {
  const DeviceCompass._();

  static const _channel = EventChannel('adhkar_app/compass');

  static Stream<double> get heading =>
      _channel.receiveBroadcastStream().map((e) => (e as num).toDouble());
}
