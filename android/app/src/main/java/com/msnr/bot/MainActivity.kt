package com.msnr.bot

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import android.webkit.WebView
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.InputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import kotlin.concurrent.thread

class MainActivity : AppCompatActivity() {
    private val PICK_IMAGE = 1001
    private val serverUrl = "http://10.0.2.2:8000/ocr-signal" // emulator localhost

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val web = findViewById<WebView>(R.id.webview)
        web.settings.javaScriptEnabled = true
        web.loadUrl("about:blank")

        val btnPick = findViewById<Button>(R.id.btnPick)
        val imgPreview = findViewById<ImageView>(R.id.imgPreview)
        val tvResult = findViewById<TextView>(R.id.tvResult)

        btnPick.setOnClickListener {
            val intent = Intent(Intent.ACTION_GET_CONTENT)
            intent.type = "image/*"
            startActivityForResult(Intent.createChooser(intent, "Select Image"), PICK_IMAGE)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE && resultCode == Activity.RESULT_OK) {
            val uri: Uri? = data?.data
            if (uri != null) {
                val imgPreview = findViewById<ImageView>(R.id.imgPreview)
                val tvResult = findViewById<TextView>(R.id.tvResult)
                try {
                    val input: InputStream? = contentResolver.openInputStream(uri)
                    val bitmap = BitmapFactory.decodeStream(input)
                    imgPreview.setImageBitmap(bitmap)

                    // save to temp file
                    val tmp = File.createTempFile("upload", ".png", cacheDir)
                    val out = FileOutputStream(tmp)
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 90, out)
                    out.flush()
                    out.close()

                    // upload in background
                    tvResult.text = "Uploading..."
                    uploadImage(tmp) { success, text ->
                        runOnUiThread {
                            if (success) tvResult.text = text else tvResult.text = "Upload failed: $text"
                        }
                    }

                } catch (e: Exception) {
                    tvResult.text = "Error: ${e.message}"
                }
            }
        }
    }

    private fun uploadImage(file: File, cb: (Boolean, String) -> Unit) {
        thread {
            val client = OkHttpClient()
            val mediaType = "image/png".toMediaTypeOrNull()
            val body = MultipartBody.Builder().setType(MultipartBody.FORM)
                .addFormDataPart("image", file.name, file.asRequestBody(mediaType))
                .build()
            val req = Request.Builder().url(serverUrl).post(body).build()
            try {
                client.newCall(req).execute().use { resp ->
                    if (!resp.isSuccessful) {
                        cb(false, "HTTP ${resp.code}")
                    } else {
                        val text = resp.body?.string() ?: "(no body)"
                        cb(true, text)
                    }
                }
            } catch (e: IOException) {
                cb(false, e.message ?: "io error")
            }
        }
    }
}
