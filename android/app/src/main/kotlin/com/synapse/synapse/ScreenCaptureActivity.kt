package com.synapse.synapse

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle

class ScreenCaptureActivity : Activity() {
    companion object {
        private const val REQUEST_CODE = 1001
        var resultCode: Int = RESULT_CANCELED
        var resultData: Intent? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE) {
            Companion.resultCode = resultCode
            resultData = data
            // Send result back to Flutter via a broadcast or start the capture service
            val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                putExtra("resultCode", resultCode)
                putExtra("resultData", data)
            }
            if (resultCode == RESULT_OK && data != null) {
                startForegroundService(serviceIntent)
            }
            finish()
        }
    }
}
