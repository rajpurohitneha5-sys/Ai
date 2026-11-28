package com.personal.ai.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.io.IOException
import java.util.concurrent.TimeUnit

/** OpenAI-compatible SSE streaming client. Cancellation is performed by cancelActive(). */
class StreamingGatewayClient(private val endpoint: String, private val token: String) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .callTimeout(150, TimeUnit.SECONDS)
        .build()

    @Volatile private var active: Call? = null

    suspend fun stream(messages: org.json.JSONArray, model: String?, onDelta: (String) -> Unit): String = withContext(Dispatchers.IO) {
        val normalized = endpoint.trim().trimEnd('/')
        val parsed = normalized.toHttpUrlOrNull() ?: throw IllegalArgumentException("Gateway URL is invalid.")
        require(parsed.scheme == "https" && parsed.host.isNotBlank()) { "Gateway URL must use HTTPS." }
        require(parsed.username.isEmpty() && parsed.password.isEmpty()) { "Do not include credentials in the gateway URL." }
        require(token.isNotBlank()) { "Gateway token is not configured." }

        val payload = JSONObject().put("messages", messages).put("stream", true)
        if (!model.isNullOrBlank()) payload.put("model", model)
        val request = Request.Builder()
            .url(normalized + "/v1/chat/completions")
            .header("Authorization", "Bearer $token")
            .header("Accept", "text/event-stream")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val call = client.newCall(request)
        active = call
        val accumulated = StringBuilder()
        var streamDone = false

        try {
            call.execute().use { response ->
                if (!response.isSuccessful) {
                    val detail = response.body?.string()?.take(400)?.trim().orEmpty()
                    val suffix = if (detail.isBlank()) "" else " — $detail"
                    throw IOException("Gateway request failed (HTTP ${response.code})$suffix")
                }
                val source = response.body?.source() ?: throw IOException("Gateway returned an empty stream.")
                var eventData = StringBuilder()

                fun processEvent() {
                    if (eventData.isEmpty()) return
                    val data = eventData.toString().trim()
                    eventData = StringBuilder()
                    if (data == "[DONE]") { streamDone = true; return }
                    if (data.isBlank()) return

                    val parsedEvent = try { JSONObject(data) } catch (_: Exception) { return }
                    if (parsedEvent.has("error")) {
                        val error = parsedEvent.optJSONObject("error")
                        throw IOException(error?.optString("message")?.takeIf { it.isNotBlank() } ?: "Gateway stream returned an error.")
                    }
                    val choice = parsedEvent.optJSONArray("choices")?.optJSONObject(0) ?: return
                    val deltaObject = choice.optJSONObject("delta") ?: choice.optJSONObject("message") ?: return
                    val contentValue = deltaObject.opt("content")
                    val delta = when (contentValue) {
                        is String -> contentValue
                        is org.json.JSONArray -> buildString {
                            for (i in 0 until contentValue.length()) {
                                val part = contentValue.optJSONObject(i)
                                if (part != null) append(part.optString("text", ""))
                            }
                        }
                        else -> ""
                    }
                    if (delta.isNotEmpty()) {
                        accumulated.append(delta)
                        onDelta(delta)
                    }
                    val finishReason = choice.optString("finish_reason")
                    if (finishReason.isNotBlank() && finishReason != "null") streamDone = true
                    if (finishReason == "tool_calls" && accumulated.isEmpty()) throw IOException("The model requested a tool action, but this app version cannot execute gateway tool calls yet.")
                }

                while (!source.exhausted() && !streamDone) {
                    val line = source.readUtf8Line() ?: break
                    when {
                        line.isEmpty() -> { processEvent(); if (streamDone) break }
                        line.startsWith("data:") -> {
                            if (eventData.isNotEmpty()) eventData.append('\n')
                            eventData.append(line.removePrefix("data:").trimStart())
                        }
                        line.startsWith(":") -> Unit // SSE keep-alive comment
                    }
                }
                if (!streamDone) processEvent()
            }
        } finally {
            if (active === call) active = null
        }

        val finalText = accumulated.toString()
        if (finalText.isBlank()) throw IOException("The gateway returned an empty response. Please retry.")
        finalText
    }

    fun cancelActive() { active?.cancel() }
}
