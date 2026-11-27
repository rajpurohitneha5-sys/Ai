package com.personal.ai.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException

/** OpenAI-compatible SSE streaming client. Cancellation is performed by cancelActive(). */
class StreamingGatewayClient(private val endpoint: String, private val token: String) {
    private val client = OkHttpClient.Builder().connectTimeout(20, java.util.concurrent.TimeUnit.SECONDS).readTimeout(0, java.util.concurrent.TimeUnit.MILLISECONDS).writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS).build()
    @Volatile private var active: Call? = null

    suspend fun stream(messages: JSONArray, model: String?, onDelta: (String) -> Unit): String = withContext(Dispatchers.IO) {
        require(endpoint.isNotBlank()) { "Gateway URL is not configured." }; val payload = JSONObject().put("messages", messages).put("stream", true)
        if (!model.isNullOrBlank()) payload.put("model", model)
        val request = Request.Builder().url(endpoint.trimEnd('/') + "/v1/chat/completions")
            .header("Authorization", "Bearer $token")
            .post(payload.toString().toRequestBody("application/json".toMediaType())).build()
        val call = client.newCall(request); active = call
        val accumulated = StringBuilder()
        try {
            call.execute().use { response ->
                if (!response.isSuccessful) throw IOException("Gateway HTTP ${response.code}: ${response.body?.string().orEmpty().take(2000)}")
                val source = response.body?.source() ?: throw IOException("Empty stream")
                while (!source.exhausted()) {
                    val line = source.readUtf8Line() ?: continue
                    if (!line.startsWith("data:")) continue
                    val data = line.removePrefix("data:").trim()
                    if (data == "[DONE]") break
                    val delta = try { JSONObject(data).optJSONArray("choices")?.optJSONObject(0)?.optJSONObject("delta")?.optString("content", "") ?: "" } catch (_: Exception) { "" }
                    if (delta.isNotEmpty()) { accumulated.append(delta); onDelta(delta) }
                }
            }
        } finally { active = null }
        accumulated.toString()
    }
    fun cancelActive() { active?.cancel() }
}
