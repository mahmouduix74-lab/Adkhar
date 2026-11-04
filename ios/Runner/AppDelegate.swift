import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let compass = CompassStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The compass is read here in the app itself rather than through a
    // plugin: every other dependency in this project resolves through Swift
    // Package Manager, and the available compass plugins are CocoaPods-only,
    // which would have made a pod install a prerequisite of every build for
    // the sake of one number.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AdhkarCompass")
    if let messenger = registrar?.messenger() {
      FlutterEventChannel(name: "adhkar_app/compass", binaryMessenger: messenger)
        .setStreamHandler(compass)
    }
  }
}

/// Streams the device's heading in degrees clockwise from true north.
///
/// `trueHeading` is negative until Core Location has a location fix to
/// resolve magnetic declination against; the magnetic heading is the honest
/// fallback until then rather than a number that is wrong by the local
/// declination without saying so.
final class CompassStreamHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
    manager.headingFilter = 1
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      // Not an error: a device without a magnetometer is a normal case the
      // Dart side already handles by locking the dial to north.
      eventSink(FlutterEndOfEventStream)
      return nil
    }
    sink = eventSink
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard let sink = sink else { return }
    let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    guard heading >= 0 else { return }
    sink(heading)
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    return true
  }
}
