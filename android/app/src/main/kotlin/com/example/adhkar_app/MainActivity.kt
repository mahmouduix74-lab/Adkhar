package com.example.adhkar_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Matches the iOS side: one event channel carrying the heading in
        // degrees clockwise from north. Kept in the app rather than pulled in
        // as a plugin so the build needs no CocoaPods on the iOS side.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "adhkar_app/compass")
            .setStreamHandler(CompassStreamHandler(this))
    }
}

private class CompassStreamHandler(private val context: Context) :
    EventChannel.StreamHandler, SensorEventListener {

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationVector: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    private var sink: EventChannel.EventSink? = null
    private val rotation = FloatArray(9)
    private val orientation = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (rotationVector == null) {
            // No compass hardware. Ending the stream is what tells the Dart
            // side to lock the dial to north and say so.
            events?.endOfStream()
            return
        }
        sink = events
        sensorManager.registerListener(
            this, rotationVector, SensorManager.SENSOR_DELAY_UI
        )
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        SensorManager.getOrientation(rotation, orientation)
        val degrees = Math.toDegrees(orientation[0].toDouble())
        sink?.success((degrees + 360.0) % 360.0)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
