package com.company.igpl

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri

class NotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "CALL_ACTION" -> {
                val phoneNumber = intent.getStringExtra("phone_number")
                if (!phoneNumber.isNullOrEmpty()) {
                    val callIntent = Intent(Intent.ACTION_CALL).apply {
                        data = Uri.parse("tel:$phoneNumber")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    try {
                        context.startActivity(callIntent)
                    } catch (e: Exception) {
                        // Fallback to dialer
                        val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:$phoneNumber")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(dialIntent)
                    }
                }
            }
            "SNOOZE_ACTION" -> {
                // Handle snooze - could send back to Flutter
                val snoozeIntent = Intent(context, MainActivity::class.java).apply {
                    putExtra("action", "snooze")
                    putExtra("follow_up_id", intent.getStringExtra("follow_up_id"))
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(snoozeIntent)
            }
            "OPEN_LEAD_ACTION" -> {
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    putExtra("action", "open_lead")
                    putExtra("lead_id", intent.getStringExtra("lead_id"))
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(openIntent)
            }
        }
    }
}