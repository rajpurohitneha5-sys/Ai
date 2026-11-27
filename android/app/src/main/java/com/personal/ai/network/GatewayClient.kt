package com.personal.ai.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Minimal gateway client. Configure endpoint/token through protected app configuration; do not hard-code secrets. */
class GatewayClient(private val endpoint: String, private val token: String) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        // Non-streaming requests and model discovery must not hang indefinitely.
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .callTimeout(90, TimeUnit.SECONDS).build()

    private fun validatedBase(): String {
        val normalized = endpoint.trim().trimEnd('/')
        val parsed = normalized.toHttpUrlOrNull() ?: throw IllegalArgumentException("Gateway URL is invalid.")
        require(parsed.scheme == "https" && parsed.host.isNotBlank()) { "Gateway URL must use HTTPS." }
        require(parsed.username.isEmpty() && parsed.password.isEmpty()) { "Do not include credentials in the gateway URL." }
        return normalized
    }

    suspend fun complete(messages: JSONArray, model: String? = null): String = withContext(Dispatchers.IO) {
        val base = validatedBase()
        require(token.isNotBlank()) { "Gateway token is not configured." }
        val payload = JSONObject().put("messages", messages).put("stream", false)
        if (!model.isNullOrBlank()) payload.put("model", model)
        val request = Request.Builder().url(base + "/v1/chat/completions")
            .header("Authorization", "Bearer $token")
            .post(payload.toString().toRequestBody("application/json".toMediaType())).build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw IllegalStateException("Gateway HTTP ${response.code}: ${body.take(2000)}")
            val root = JSONObject(body)
            root.optJSONArray("choices")?.optJSONObject(0)?.optJSONObject("message")?.optString("content")
                ?: throw IllegalStateException("Unexpected gateway response")
        }
    }

    suspend fun listModels(): JSONArray = withContext(Dispatchers.IO) {
        val base = validatedBase()
        require(token.isNotBlank()) { "Gateway token is not configured." }
        val request = Request.Builder().url(base + "/v1/models")
            .header("Authorization", "Bearer $token").get().build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw IllegalStateException("Gateway HTTP ${response.code}: ${body.take(2000)}")
            JSONObject(body).optJSONArray("data") ?: JSONArray()
        }
    }
}
