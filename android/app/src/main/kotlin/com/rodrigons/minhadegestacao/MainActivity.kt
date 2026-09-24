package com.rodrigons.minhadegestacao

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "minha_gestacao/links")
            .setMethodCallHandler { chamada, resultado ->
                if (chamada.method != "abrir") {
                    resultado.notImplemented()
                    return@setMethodCallHandler
                }

                val url = chamada.argument<String>("url")
                if (url == null || !url.startsWith("https://")) {
                    resultado.success(false)
                    return@setMethodCallHandler
                }

                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    resultado.success(true)
                } catch (erro: ActivityNotFoundException) {
                    resultado.success(false)
                }
            }
    }
}
