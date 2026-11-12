package com.example.do_it

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.abs
import kotlin.math.min

/**
 * `doit/text_recognition` 채널의 Android 쪽. ML Kit 한국어 모델로 사진 속 글자를 줄 단위로 읽는다.
 *
 * 모델은 APK에 포함된 번들 모델(`com.google.mlkit:text-recognition-korean`)이라
 * 내려받기나 네트워크 없이 단말 안에서만 처리한다. 한국어 인식기는 라틴 문자도 함께 읽는다.
 */
class TextRecognitionHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val recognizer by lazy {
        TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
    }

    /** Dart에서 온 호출을 이름에 따라 미리 읽기나 줄 인식으로 나눈다. */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "warmUp" -> warmUp(result)
            "recognizeLines" -> recognizeLines(call, result)
            else -> result.notImplemented()
        }
    }

    /** 빈 그림을 한 번 인식시켜 모델을 메모리에 올려 둔다. 첫 인식이 수 초 걸리는 것을 줄인다. */
    private fun warmUp(result: MethodChannel.Result) {
        val blank = Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888)
        recognizer.process(InputImage.fromBitmap(blank, 0))
            .addOnCompleteListener {
                blank.recycle()
                result.success(null)
            }
    }

    /**
     * `path`의 사진을 읽어 줄 목록을 돌려준다.
     *
     * 사진을 열지 못하거나 인식이 실패하면 오류 코드를 Dart에 돌려준다.
     */
    private fun recognizeLines(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("invalidArgs", "path가 없습니다.", null)
            return
        }

        val image = try {
            // fromFilePath는 EXIF 회전 정보를 반영한다.
            InputImage.fromFilePath(context, Uri.fromFile(File(path)))
        } catch (error: Exception) {
            result.error("imageLoadFailed", error.message, null)
            return
        }

        recognizer.process(image)
            .addOnSuccessListener { text ->
                val lines = text.textBlocks.flatMap { it.lines }
                result.success(mergeRows(lines))
            }
            .addOnFailureListener { error ->
                result.error("recognitionFailed", error.message, null)
            }
    }

    /**
     * ML Kit는 단어 사이가 넓으면 한 줄을 여러 블록으로 나눠 돌려준다.
     * 세로 위치가 겹치는 줄은 한 줄로 보고 왼쪽부터 이어 붙여, 위에서 아래 순서로 돌려준다.
     */
    private fun mergeRows(lines: List<Text.Line>): List<String> {
        val rows = mutableListOf<MutableList<Text.Line>>()
        for (line in lines.sortedBy { it.boundingBox?.centerY() ?: 0 }) {
            val box = line.boundingBox
            val row = rows.lastOrNull()
            val rowBox = row?.first()?.boundingBox
            val isSameRow = box != null && rowBox != null &&
                abs(box.centerY() - rowBox.centerY()) < min(box.height(), rowBox.height()) / 2
            if (isSameRow) row!!.add(line) else rows.add(mutableListOf(line))
        }
        return rows.map { row ->
            row.sortedBy { it.boundingBox?.left ?: 0 }.joinToString(" ") { it.text }
        }
    }

    /** 인식기를 닫는다. 엔진이 정리될 때 [MainActivity]가 부른다. */
    fun close() {
        recognizer.close()
    }
}
