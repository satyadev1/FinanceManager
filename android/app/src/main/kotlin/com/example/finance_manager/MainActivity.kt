package com.example.finance_manager

import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.finance_manager/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInboxSms" -> {
                        val sinceMs = call.argument<Long>("sinceMs") ?: 0L
                        try {
                            val messages = readSms(sinceMs)
                            result.success(messages)
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSms(sinceMs: Long): List<Map<String, Any?>> {
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )
        val selection = if (sinceMs > 0) "${Telephony.Sms.DATE} > ?" else null
        val selectionArgs = if (sinceMs > 0) arrayOf(sinceMs.toString()) else null
        val sortOrder = "${Telephony.Sms.DATE} DESC"

        val messages = mutableListOf<Map<String, Any?>>()
        val cursor: Cursor? = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)

        cursor?.use {
            val addressIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext()) {
                messages.add(mapOf(
                    "address" to it.getString(addressIdx),
                    "body" to it.getString(bodyIdx),
                    "date" to it.getLong(dateIdx)
                ))
            }
        }

        return messages
    }
}
