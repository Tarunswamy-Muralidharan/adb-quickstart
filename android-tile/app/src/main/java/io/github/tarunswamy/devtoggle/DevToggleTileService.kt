package io.github.tarunswamy.devtoggle

import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

class DevToggleTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()
        val cr = contentResolver
        val devOn = Settings.Global.getInt(cr, KEY_DEV, 0) == 1

        try {
            if (devOn) {
                Settings.Global.putInt(cr, KEY_ADB, 0)
                Settings.Global.putInt(cr, KEY_DEV, 0)
            } else {
                Settings.Global.putInt(cr, KEY_DEV, 1)
                Settings.Global.putInt(cr, KEY_ADB, 1)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "WRITE_SECURE_SETTINGS not granted. Run: adb shell pm grant $PKG android.permission.WRITE_SECURE_SETTINGS", e)
        }

        refreshTile()
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val devOn = Settings.Global.getInt(contentResolver, KEY_DEV, 0) == 1
        tile.state = if (devOn) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.tile_label)
        tile.contentDescription = getString(if (devOn) R.string.tile_on else R.string.tile_off)
        tile.updateTile()
    }

    companion object {
        private const val TAG = "DevToggleTile"
        private const val PKG = "io.github.tarunswamy.devtoggle"
        private const val KEY_DEV = "development_settings_enabled"
        private const val KEY_ADB = "adb_enabled"
    }
}
