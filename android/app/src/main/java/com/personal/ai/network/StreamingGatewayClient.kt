package com.personal.ai.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/** OpenAI-compatible SSE streaming client. Cancellation is performed by cancelActive(). */
class StreamingGatewayClient(private val endpoint: String, private val token: String) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    @Volatile private var active: Call? = null

    suspend fun stream(messages: org.json.JSONArray, model: String?, onDelta: (String) -> Unit): String = withContext(Dispatchers.IO) {
        require(endpoint.isNotBlank()) { "Gateway URL is not configured." }
        val payload = JSONObject().put("messages", messages).put("stream", true)
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
                var eventData = StringBuilder()
                fun processEvent() {
                    if (eventData.isEmpty()) return
                    val data = eventData.toString().trim()
                    eventData = StringBuilder()
                    if (data == "[DONE]") return
                    try {
                        val choice = JSONObject(data).optJSONArray("choices")?.optJSONObject(0) ?: return
                        val deltaObj = choice.optJSONObject("delta") ?: choice.optJSONObject("message") ?: return
                        val contentValue = deltaObj.opt("content")
                        val delta = when (contentValue) {
                            is String -> contentValue
                            is org.json.JSONArray -> buildString { for (i in 0 until contentValue.length()) { val part=contentValue.optJSONObject(i); if(part!=null) append(part.optString("text","")) } }
                            else -> ""
                        }
                        if (delta.isNotEmpty()) { accumulated.append(delta); onDelta(delta) }
                        val finish = choice.optString("finish_reason")
                        if (finish == "stop") { /* frame consumed; [DONE] remains optional */ }
                    } catch (_: Exception) { /* Ignore malformed/non-content SSE frames. */ }
                }
                while (!source.exhausted()) {
                    val line = source.readUtf8Line() ?: break
                    if (line.isEmpty()) { processEvent(); continue }
                    if (line.startsWith("data:")) {
                        if (eventData.isNotEmpty()) eventData.append('\n')
                        eventData.append(line.removePrefix("data:").trimStart())
                    }
                }
                processEvent()
            }
        } finally { active = null }
        accumulated.toString()
    }
    fun cancelActive() { active?.cancel() }
}
