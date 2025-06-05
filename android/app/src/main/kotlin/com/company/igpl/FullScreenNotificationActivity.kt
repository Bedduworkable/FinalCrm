package com.company.igpl

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.Color

class FullScreenNotificationActivity : Activity() {

    private var leadName: String? = null
    private var followUpTitle: String? = null
    private var phoneNumber: String? = null
    private var leadId: String? = null
    private var followUpId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make activity show over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // Keep screen on and make fullscreen
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )

        // Get data from intent
        extractIntentData()

        // Create the overlay UI
        createSimpleUI()
    }

    private fun extractIntentData() {
        leadName = intent.getStringExtra("lead_name") ?: "Unknown Lead"
        followUpTitle = intent.getStringExtra("follow_up_title") ?: "Follow-up Due"
        phoneNumber = intent.getStringExtra("phone_number") ?: ""
        leadId = intent.getStringExtra("lead_id") ?: ""
        followUpId = intent.getStringExtra("follow_up_id") ?: ""
    }

    private fun createSimpleUI() {
        // Create main layout
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            setPadding(60, 200, 60, 200)
        }

        // Header text
        val headerText = TextView(this).apply {
            text = "Follow-up Reminder"
            setTextColor(Color.WHITE)
            textSize = 18f
            textAlignment = View.TEXT_ALIGNMENT_CENTER
        }

        // Lead name
        val leadNameText = TextView(this).apply {
            text = leadName
            setTextColor(Color.WHITE)
            textSize = 26f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPadding(0, 100, 0, 30)
        }

        // Follow-up title
        val followUpText = TextView(this).apply {
            text = followUpTitle
            setTextColor(Color.parseColor("#CCFFFFFF"))
            textSize = 18f
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPadding(0, 0, 0, 150)
        }

        // Button container
        val buttonLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 100, 0, 0)
        }

        // Decline button
        val declineButton = Button(this).apply {
            text = "Snooze"
            setBackgroundColor(Color.RED)
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(40, 40, 40, 40)
            layoutParams = LinearLayout.LayoutParams(0, 200).apply {
                weight = 1f
                setMargins(0, 0, 30, 0)
            }
            setOnClickListener { handleDecline() }
        }

        // Accept button
        val acceptButton = Button(this).apply {
            text = "Call Now"
            setBackgroundColor(Color.GREEN)
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(40, 40, 40, 40)
            layoutParams = LinearLayout.LayoutParams(0, 200).apply {
                weight = 1f
                setMargins(30, 0, 0, 0)
            }
            setOnClickListener { handleAccept() }
        }

        // Add buttons to container
        buttonLayout.addView(declineButton)
        buttonLayout.addView(acceptButton)

        // Add all views to main layout
        mainLayout.addView(headerText)
        mainLayout.addView(leadNameText)
        mainLayout.addView(followUpText)
        mainLayout.addView(buttonLayout)

        setContentView(mainLayout)
    }

    private fun handleAccept() {
        // Make phone call
        if (!phoneNumber.isNullOrEmpty()) {
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$phoneNumber")
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback to dialer
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                }
                startActivity(dialIntent)
            }
        }

        // Open main app
        openMainApp()
        finish()
    }

    private fun handleDecline() {
        // Just dismiss for now
        finish()
    }

    private fun openMainApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("lead_id", leadId)
            putExtra("follow_up_id", followUpId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        intent?.let { startActivity(it) }
    }

    override fun onBackPressed() {
        // Prevent back button from closing
        // User must use the buttons
    }
}