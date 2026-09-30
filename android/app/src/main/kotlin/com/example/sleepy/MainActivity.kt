package com.example.sleepy

import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational

class MainActivity: PipCallbackHelperActivityWrapper() {

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val builder = PictureInPictureParams.Builder()
                builder.setAspectRatio(Rational(1, 1))
                val params: PictureInPictureParams = builder.build()
                enterPictureInPictureMode(params)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}