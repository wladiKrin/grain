package io.github.wladikrin.grain

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.wladikrin.grain.location.LocationPlugin
import io.github.wladikrin.grain.meter.MeterPlugin
import io.github.wladikrin.grain.save.SavePlugin
import io.github.wladikrin.grain.sound.ClickPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(MeterPlugin())
        flutterEngine.plugins.add(LocationPlugin())
        flutterEngine.plugins.add(ClickPlugin())
        flutterEngine.plugins.add(SavePlugin())
    }
}
