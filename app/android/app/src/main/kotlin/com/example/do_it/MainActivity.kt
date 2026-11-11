package com.example.do_it

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var textRecognition: TextRecognitionHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val handler = TextRecognitionHandler(applicationContext)
        textRecognition = handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doit/text_recognition")
            .setMethodCallHandler(handler)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        textRecognition?.close()
        textRecognition = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
