package io.github.tarunswamy.devtoggle

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {

    private lateinit var statusPermission: TextView
    private lateinit var statusDevOptions: TextView
    private lateinit var statusUsbDebug: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildLayout())
    }

    override fun onResume() {
        super.onResume()
        refreshStatus()
    }

    private fun refreshStatus() {
        val granted = checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED
        val devOn = Settings.Global.getInt(contentResolver, "development_settings_enabled", 0) == 1
        val adbOn = Settings.Global.getInt(contentResolver, "adb_enabled", 0) == 1

        statusPermission.text = if (granted) "Permission: granted" else "Permission: NOT granted (run the adb command below)"
        statusPermission.setTextColor(if (granted) 0xFF0F766E.toInt() else 0xFFB91C1C.toInt())

        statusDevOptions.text = "Developer options: " + if (devOn) "ON" else "OFF"
        statusUsbDebug.text = "USB debugging: " + if (adbOn) "ON" else "OFF"
    }

    private fun buildLayout(): View {
        val padding = dp(20)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
        }

        root.addView(makeTitle("Dev Toggle"))
        root.addView(makeSubtitle("One-tap toggle for Developer options + USB debugging"))
        root.addView(spacer(dp(16)))

        root.addView(makeSectionHeader("1. Grant the secure-settings permission"))
        root.addView(makeBody("From your computer (phone connected via USB, USB debugging on), run:"))

        val cmd = "adb shell pm grant $packageName android.permission.WRITE_SECURE_SETTINGS"
        root.addView(makeCodeBlock(cmd))

        val copyBtn = Button(this).apply {
            text = "Copy command"
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("adb command", cmd))
                Toast.makeText(this@MainActivity, "Copied", Toast.LENGTH_SHORT).show()
            }
        }
        root.addView(copyBtn)

        root.addView(spacer(dp(16)))
        root.addView(makeSectionHeader("2. Add the tile to Quick Settings"))
        root.addView(makeBody("Swipe down twice to open Quick Settings, tap the pencil/edit icon, then drag the \"Dev Options\" tile into your active tiles. Save."))

        root.addView(spacer(dp(16)))
        root.addView(makeSectionHeader("3. Tap the tile"))
        root.addView(makeBody("Tap once: Developer options + USB debugging both turn OFF (UPI apps run normally).\nTap again: both turn back ON."))

        root.addView(spacer(dp(20)))
        root.addView(makeSectionHeader("Live status"))

        statusPermission = makeBody("Permission: …")
        statusDevOptions = makeBody("Developer options: …")
        statusUsbDebug = makeBody("USB debugging: …")
        root.addView(statusPermission)
        root.addView(statusDevOptions)
        root.addView(statusUsbDebug)

        root.addView(spacer(dp(16)))
        val refreshBtn = Button(this).apply {
            text = "Refresh status"
            setOnClickListener { refreshStatus() }
        }
        root.addView(refreshBtn)

        val scroll = ScrollView(this)
        scroll.addView(root)
        return scroll
    }

    private fun makeTitle(text: String) = TextView(this).apply {
        this.text = text
        setTypeface(typeface, Typeface.BOLD)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
    }

    private fun makeSubtitle(text: String) = TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        alpha = 0.75f
    }

    private fun makeSectionHeader(text: String) = TextView(this).apply {
        this.text = text
        setTypeface(typeface, Typeface.BOLD)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        setPadding(0, dp(8), 0, dp(4))
    }

    private fun makeBody(text: String) = TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        setPadding(0, dp(2), 0, dp(2))
    }

    private fun makeCodeBlock(text: String) = TextView(this).apply {
        this.text = text
        typeface = Typeface.MONOSPACE
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        setTextIsSelectable(true)
        val pad = dp(12)
        setPadding(pad, pad, pad, pad)
        background = GradientDrawable().apply {
            cornerRadius = dp(8).toFloat()
            setColor(Color.parseColor("#11000000"))
        }
        val lp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(6); bottomMargin = dp(6) }
        layoutParams = lp
    }

    private fun spacer(h: Int) = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, h)
    }

    private fun dp(v: Int): Int =
        (v * resources.displayMetrics.density).toInt()
}
