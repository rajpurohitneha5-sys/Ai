package com.personal.ai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import com.personal.ai.network.GatewayClient
import com.personal.ai.network.StreamingGatewayClient
import com.personal.ai.data.ChatStore
import com.personal.ai.data.WorkspaceStore

private val Black = Color(0xFF101010)
private val Panel = Color(0xFF1B1B1B)
private val Gold = Color(0xFFD6B45B)
private val White = Color(0xFFF5F5F5)

data class ChatMessage(val text: String, val isUser: Boolean, val id: String)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = EncryptedSharedPreferences.create(
            "ai_config_secure",
            "ai_config_master_key",
            this,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
        val oldPrefs = getSharedPreferences("ai_config", MODE_PRIVATE)
        if (!prefs.contains("endpoint") && !prefs.contains("token") &&
            (oldPrefs.contains("endpoint") || oldPrefs.contains("token"))) {
            val ok = prefs.edit()
                .putString("endpoint", oldPrefs.getString("endpoint", "") ?: "")
                .putString("token", oldPrefs.getString("token", "") ?: "")
                .commit()
            if (ok) oldPrefs.edit().clear().commit()
        }
        val legacy = ChatStore(this)
        val workspace = WorkspaceStore(this)
        workspace.migrateLegacy(legacy.load())
        setContent {
            AIApp(
                prefs.getString("endpoint", "") ?: "",
                prefs.getString("token", "") ?: "",
                workspace,
                { endpoint, token -> prefs.edit().putString("endpoint", endpoint).putString("token", token).apply() }
            )
        }
    }
}

@Composable
fun AIApp(initialEndpoint: String, initialToken: String, store: WorkspaceStore, saveConfig: (String, String) -> Unit) {
    val clipboard = LocalClipboardManager.current
    var input by remember { mutableStateOf("") }
    var endpoint by remember { mutableStateOf(initialEndpoint) }
    var token by remember { mutableStateOf(initialToken) }
    var model by remember { mutableStateOf(store.listConversations().firstOrNull { !it.archived }?.model ?: "") }
    var modelList by remember { mutableStateOf<List<String>>(emptyList()) }
    var modelMenu by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var historyOpen by remember { mutableStateOf(false) }
    var historySearch by remember { mutableStateOf("") }
    var historyRevision by remember { mutableIntStateOf(0) }
    var showArchived by remember { mutableStateOf(false) }
    var renameId by remember { mutableStateOf<String?>(null) }
    var renameTitle by remember { mutableStateOf("") }
    var selectedId by remember { mutableStateOf(store.listConversations().firstOrNull { !it.archived }?.id) }
    var messages by remember { mutableStateOf<List<ChatMessage>>(selectedId?.let { id -> store.messages(id).map { ChatMessage(it.content, it.role == "user", it.id) } } ?: emptyList()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    var activeCall by remember { mutableStateOf<StreamingGatewayClient?>(null) }
    val chatListState = rememberLazyListState()

    fun loadChat(id: String?) {
        selectedId = id
        val chat = id?.let { key -> store.listConversations().firstOrNull { it.id == key } }
        if (chat != null && chat.model.isNotBlank()) model = chat.model
        messages = id?.let { key -> store.messages(key).map { m -> ChatMessage(m.content, m.role == "user", m.id) } } ?: emptyList()
    }
    fun newChat() {
        val id = store.createConversation("New chat", model)
        loadChat(id)
        error = ""
        historyOpen = false
    }

    MaterialTheme(colorScheme = darkColorScheme(background = Black, surface = Panel, primary = Gold, onPrimary = Black)) {
        Column(Modifier.fillMaxSize().background(Black)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("AI", color = Gold, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                IconButton(onClick = { historyOpen = true }) { Icon(Icons.Default.History, "Chat history", tint = Gold) }
                IconButton(onClick = { newChat() }, enabled = !busy) { Icon(Icons.Default.Add, "New chat", tint = Gold) }
                Spacer(Modifier.weight(1f))
                Box {
                    TextButton(onClick = { modelMenu = true }) { Text(if (model.isBlank()) "Choose model" else model, color = Gold) }
                    DropdownMenu(expanded = modelMenu, onDismissRequest = { modelMenu = false }) {
                        modelList.forEach { m ->
                            DropdownMenuItem(text = { Text(m) }, onClick = { model = m; modelMenu = false; selectedId?.let { store.touchConversation(it, m) } })
                        }
                        DropdownMenuItem(text = { Text("Refresh models") }, onClick = {
                            modelMenu = false
                            scope.launch {
                                error = ""
                                try {
                                    val arr = GatewayClient(endpoint, token).listModels()
                                    modelList = (0 until arr.length()).map { arr.getJSONObject(it).optString("id") }.filter { it.isNotBlank() }
                                    if (model.isBlank() && modelList.isNotEmpty()) model = modelList.first()
                                } catch (e: Exception) { error = e.message ?: "Unable to load models" }
                            }
                        })
                    }
                }
                TextButton(onClick = { settingsOpen = true }) { Text("Settings", color = Gold) }
            }

            if (settingsOpen) AlertDialog(
                onDismissRequest = { settingsOpen = false },
                title = { Text("Gateway configuration") },
                text = { Column {
                    OutlinedTextField(endpoint, { endpoint = it }, label = { Text("Gateway URL") })
                    OutlinedTextField(token, { token = it }, label = { Text("Gateway token") }, visualTransformation = PasswordVisualTransformation())
                } },
                confirmButton = { TextButton(onClick = { saveConfig(endpoint.trim(), token.trim()); settingsOpen = false }) { Text("Save") } },
                dismissButton = { TextButton(onClick = { settingsOpen = false }) { Text("Cancel") } }
            )

            if (historyOpen) {
                val chats = store.listConversations(historySearch).filter { it.archived == showArchived }
                AlertDialog(
                    onDismissRequest = { historyOpen = false },
                    title = { Text("Chats") },
                    text = { Column(Modifier.heightIn(max = 460.dp)) {
                        OutlinedTextField(historySearch, { historySearch = it }, label = { Text("Search chats") }, modifier = Modifier.fillMaxWidth())
                        TextButton(onClick = { showArchived = !showArchived; historyRevision++ }) { Text(if (showArchived) "Show active chats" else "Show archived chats", color = Gold) }
                        LazyColumn {
                            items(chats, key = { it.id }) { chat ->
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    TextButton(onClick = { loadChat(chat.id); historyOpen = false }) { Text((if (chat.pinned) "★ " else "") + chat.title, color = White) }
                                    TextButton(onClick = { renameId = chat.id; renameTitle = chat.title }) { Text("Rename", color = Gold) }
                                    TextButton(onClick = { store.setPinned(chat.id, !chat.pinned); historyRevision++ }) { Text(if (chat.pinned) "Unpin" else "Pin", color = Gold) }
                                    TextButton(onClick = { store.setArchived(chat.id, !chat.archived); historyRevision++; if (selectedId == chat.id) loadChat(null) }) { Text(if (chat.archived) "Unarchive" else "Archive", color = Gold) }
                                    TextButton(onClick = { store.deleteConversation(chat.id); historyRevision++; if (selectedId == chat.id) loadChat(null) }) { Text("Delete", color = Color.Red) }
                                }
                            }
                        }
                    } },
                    confirmButton = { TextButton(onClick = { historyOpen = false }) { Text("Close") } },
                    dismissButton = { TextButton(onClick = { newChat() }) { Text("New chat") } }
                )
            }
            if (renameId != null) AlertDialog(
                onDismissRequest = { renameId = null }, title = { Text("Rename chat") },
                text = { OutlinedTextField(renameTitle, { renameTitle = it }, label = { Text("Chat title") }) },
                confirmButton = { TextButton(onClick = { renameId?.let { id -> store.renameConversation(id, renameTitle.trim().ifBlank { "New chat" }) }; historyRevision++; renameId = null }) { Text("Save") } },
                dismissButton = { TextButton(onClick = { renameId = null }) { Text("Cancel") } }
            )

            if (messages.isEmpty()) {
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("AI", color = Gold, fontSize = 42.sp, fontWeight = FontWeight.Bold)
                        Text("What can I help you with?", color = White, fontSize = 20.sp)
                        Text("Personal AI workspace", color = Color.Gray, modifier = Modifier.padding(top = 8.dp))
                    }
                }
            } else {
                LaunchedEffect(messages.size, messages.lastOrNull()?.text?.length) {
                    if (messages.isNotEmpty()) chatListState.scrollToItem(messages.lastIndex)
                }
                LazyColumn(state = chatListState, modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
                    items(messages, key = { it.id }) { msg ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = if (msg.isUser) Arrangement.End else Arrangement.Start) {
                            Surface(color = if (msg.isUser) Color(0xFF29251B) else Panel, shape = RoundedCornerShape(16.dp), modifier = Modifier.padding(vertical = 5.dp).widthIn(max = 340.dp)) {
                                Column(Modifier.padding(10.dp)) {
                                    MarkdownText(msg.text, modifier = Modifier.padding(2.dp))
                                    if (msg.text.isNotBlank()) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                                        IconButton(onClick = { clipboard.setText(AnnotatedString(msg.text)) }, modifier = Modifier.size(28.dp)) {
                                            Icon(Icons.Default.ContentCopy, contentDescription = "Copy message", tint = Color.Gray, modifier = Modifier.size(16.dp))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if (busy) Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Generating…", color = Gold); Spacer(Modifier.weight(1f))
                TextButton(onClick = { activeCall?.cancelActive() }) { Icon(Icons.Default.Stop, "Stop", tint = Gold); Text("Stop", color = Gold) }
            }
            if (error.isNotBlank()) Text(error, color = Color(0xFFFF8A80), modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
            Row(Modifier.fillMaxWidth().padding(12.dp).background(Panel, RoundedCornerShape(24.dp)).padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                TextField(value = input, onValueChange = { input = it }, modifier = Modifier.weight(1f), placeholder = { Text("Message AI…", color = Color.Gray) }, colors = TextFieldDefaults.colors(focusedTextColor = White, unfocusedTextColor = White, focusedContainerColor = Panel, unfocusedContainerColor = Panel, focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent))
                IconButton(enabled = input.isNotBlank() && !busy, onClick = {
                    val prompt = input.trim()
                    input = ""; error = ""
                    val cid = selectedId ?: store.createConversation("New chat", model).also { selectedId = it; messages = emptyList() }
                    if (store.messages(cid).isEmpty()) store.renameConversation(cid, prompt.take(64).ifBlank { "New chat" })
                    val userMessageId = store.addMessage(cid, "user", prompt)
                    messages = messages + ChatMessage(prompt, true, userMessageId)
                    busy = true
                    scope.launch {
                        var assistantId: String? = null
                        var streamed = ""
                        try {
                            val payload = JSONArray()
                            store.messages(cid).filter { it.status != "streaming" }.forEach { payload.put(JSONObject().put("role", it.role).put("content", it.content)) }
                            val client = StreamingGatewayClient(endpoint, token)
                            activeCall = client
                            assistantId = store.addMessage(cid, "assistant", "", "streaming")
                            messages = messages + ChatMessage("", false, assistantId!!)
                            val answer = client.stream(payload, model.takeIf { it.isNotBlank() }) { delta ->
                                streamed += delta
                                scope.launch(Dispatchers.Main.immediate) { messages = messages.map { msg -> if (msg.id == assistantId) msg.copy(text = streamed) else msg } }
                            }
                            if (streamed.isBlank()) streamed = answer
                            messages = messages.map { msg -> if (msg.id == assistantId) msg.copy(text = streamed) else msg }
                            assistantId?.let { store.updateMessage(it, streamed, "complete") }
                            store.touchConversation(cid, model)
                        } catch (e: Exception) {
                            error = e.message ?: "Request failed"
                            if (assistantId != null) {
                                val savedText = streamed.ifBlank { "Generation stopped or failed. Please retry." }
                                messages = messages.map { msg -> if (msg.id == assistantId) msg.copy(text = savedText) else msg }
                                assistantId?.let { store.updateMessage(it, savedText, "interrupted") }
                            } else {
                                messages = messages + ChatMessage("I couldn't complete that request. Check your connection and gateway configuration, then retry.", false, java.util.UUID.randomUUID().toString())
                            }
                        } finally {
                            busy = false; activeCall = null; loadChat(cid)
                        }
                    }
                }) { Icon(Icons.Default.Send, "Send", tint = Gold) }
            }
            Text("Personal AI · gateway-connected chat foundation", color = Color.Gray, fontSize = 10.sp, modifier = Modifier.align(Alignment.CenterHorizontally).padding(bottom = 6.dp))
        }
    }
}

@Composable
private fun MarkdownText(text: String, modifier: Modifier = Modifier) {
    val annotated = buildAnnotatedString {
        var inCodeBlock = false
        text.lines().forEachIndexed { index, line ->
            if (index > 0) append("\n")
            if (line.trim().startsWith("```")) {
                inCodeBlock = !inCodeBlock
                return@forEachIndexed
            }
            val trimmed = line.trimStart()
            val heading = Regex("^#{1,3}\\s+(.+)$").find(trimmed)?.groupValues?.get(1)
            val bullet = Regex("^(?:[-*] |\\d+\\. )(.+)$").find(trimmed)?.groupValues?.get(1)
            val content = heading ?: bullet ?: line
            if (heading != null) withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = Gold)) { append(heading) }
            else if (inCodeBlock) withStyle(SpanStyle(fontFamily = FontFamily.Monospace, color = Gold, background = Color(0xFF292929))) { append(line) }
            else {
                if (bullet != null) append("• ")
                val pattern = Regex("\\*\\*(.+?)\\*\\*|\\x60(.+?)\\x60")
                var cursor = 0
                pattern.findAll(content).forEach { match ->
                    append(content.substring(cursor, match.range.first))
                    val bold = match.groups[1]?.value
                    val code = match.groups[2]?.value
                    if (bold != null) withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(bold) }
                    else if (code != null) withStyle(SpanStyle(fontFamily = FontFamily.Monospace, color = Gold)) { append(code) }
                    cursor = match.range.last + 1
                }
                append(content.substring(cursor))
            }
        }
    }
    Text(annotated, color = White, modifier = modifier)
}
