package com.example.do_it

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** 앱의 Android 진입 화면. Flutter 엔진에 글자 인식 채널을 연결한다. */
class MainActivity : FlutterActivity() {

    private var textRecognition: TextRecognitionHandler? = null

    /** 엔진이 준비되면 `doit/text_recognition` 채널에 ML Kit 인식기를 연결한다. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val handler = TextRecognitionHandler(applicationContext)
        textRecognition = handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doit/text_recognition")
            .setMethodCallHandler(handler)
    }

    /** 엔진이 정리될 때 인식기를 닫아 모델이 쓰던 메모리를 놓는다. */
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        textRecognition?.close()
        textRecognition = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
