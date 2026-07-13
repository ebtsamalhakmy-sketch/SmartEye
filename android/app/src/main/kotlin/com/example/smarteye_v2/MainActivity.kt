package com.example.smarteye_v2

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.smarteye_v2/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openVoiceInputSettings" -> {
                    launchSettings(Settings.ACTION_VOICE_INPUT_SETTINGS, result)
                }
                "openDefaultAppsSettings" -> {
                    launchSettings(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS, result)
                }
                "openInputMethodSettings" -> {
                    launchSettings(Settings.ACTION_INPUT_METHOD_SETTINGS, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun launchSettings(action: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(action)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                startActivity(intent)
                result.success(true)
            } catch (ex: Exception) {
                result.error("UNAVAILABLE", "Could not open settings: ${ex.message}", null)
            }
        }
    }
}
