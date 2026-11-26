import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
const String mySecretKey = "AQ.Ab8RN6LVwavoZSPnRADf_XKcn6AQH6nCv-Kgfa1ziEN6UQY9XA";

void main() => runApp(const ChatGPTApp());

class ChatGPTApp extends StatelessWidget {
  const ChatGPTApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _keyInput = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  List<List<ChatMessage>> _history = [];
  String _model = "Gemini 1.5 Flash";
  bool _loading = false;
  String _savedKey = mySecretKey;
  String _githubToken = '';
  String _githubOwner = '';
  String _githubRepo = 'ai';

  void _newChat() {
    if (_messages.isNotEmpty) _history.insert(0, List.from(_messages));
    setState(() => _messages = []);
    try { Navigator.pop(context); } catch (e) {}
  }

  void _loadHistory(int i) {
    setState(() { _messages = List.from(_history[i]); });
    Navigator.pop(context);
  }

  Future<void> _pushToGithub(String fileName, String code) async {
    if (_githubToken.isEmpty || _githubOwner.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('First set GitHub in Drawer!')));
      _showGithubDialog();
      return;
    }
    final url = Uri.parse('https://api.github.com/repos/$_githubOwner/$_githubRepo/contents/$fileName');
    String? sha;
    try {
      final getRes = await http.get(url, headers: {'Authorization': 'Bearer $_githubToken'});
      if (getRes.statusCode == 200) sha = jsonDecode(getRes.body)['sha'];
    } catch (e) {}
    final res = await http.put(url,
      headers: {'Authorization': 'Bearer $_githubToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'message': 'Update from AI App', 'content': base64Encode(utf8.encode(code)), if (sha != null) 'sha': sha}),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.statusCode == 200 || res.statusCode == 201 ? 'Pushed to GitHub ✅' : 'Failed! Check Token/Repo')));
  }

  void _showGithubDialog() {
    final tokenCtrl = TextEditingController(text: _githubToken);
    final ownerCtrl = TextEditingController(text: _githubOwner);
    final repoCtrl = TextEditingController(text: _githubRepo);
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Connect GitHub'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'GitHub Username')),
        TextField(controller: repoCtrl, decoration: const InputDecoration(labelText: 'Repo Name')),
        TextField(controller: tokenCtrl, decoration: const InputDecoration(labelText: 'Token ghp_...'), obscureText: true),
      ]),
      actions: [TextButton(onPressed: () { setState(() { _githubToken = tokenCtrl.text.trim(); _githubOwner = ownerCtrl.text.trim(); _githubRepo = repoCtrl.text.trim(); }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GitHub Connected ✅'))); }, child: const Text('Save'))],
    ));
  }

  void _showPushDialog(String code) {
    final nameCtrl = TextEditingController(text: 'main.dart');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Push to GitHub'),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'File Name e.g. main.dart')),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _pushToGithub(nameCtrl.text.trim(), code); }, child: const Text('Push ✅'))],
    ));
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    if (_savedKey.isEmpty) { _showKeyDialog(); return; }
    setState(() { _messages.add(ChatMessage(text, true)); _loading = true; _input.clear(); });
    _scrollDown();
    try {
      final modelId = _model.contains("Pro") ? "gemini-1.5-pro" : "gemini-1.5-flash";
      final res = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$_savedKey"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"contents": [{"parts": [{"text": text}]}]}));
      String reply = "Error";
      if (res.statusCode == 200) {
        reply = jsonDecode(res.body)["candidates"][0]["content"]["parts"][0]["text"].toString();
      } else {
        reply = "API Error: Check Key. ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}";
      }
      setState(() => _messages.add(ChatMessage(reply, false)));
    } catch (e) {
      setState(() => _messages.add(ChatMessage("Error: $e", false)));
    }
    setState(() => _loading = false);
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _showKeyDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Enter Gemini API Key"),
      content: TextField(controller: _keyInput, decoration: const InputDecoration(hintText: "AIzaSy...")),
      actions: [TextButton(onPressed: () { setState(() => _savedKey = _keyInput.text.trim()); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Key Saved! Now Chat!"))); }, child: const Text("Save"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 50, 16, 20), color: Colors.black,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset("logo.png", height: 50, errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, color: Colors.white, size: 40)),
              const SizedBox(height: 10),
              const Text("AI Super App", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("ChatGPT Clone + GitHub", style: TextStyle(color: Colors.grey)),
            ]),
          ),
          ListTile(leading: const Icon(Icons.add), title: const Text("New Chat"), onTap: _newChat),
          ListTile(leading: const Icon(Icons.key), title: const Text("Set API Key"), onTap: () { Navigator.pop(context); _showKeyDialog(); }),
          ListTile(leading: const Icon(Icons.code), title: const Text("Connect GitHub"), onTap: () { Navigator.pop(context); _showGithubDialog(); }),
          const Divider(),
          const Padding(padding: EdgeInsets.all(8), child: Text("CHAT HISTORY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: _history.isEmpty ? const Center(child: Text("No chats yet")) : ListView.builder(itemCount: _history.length, itemBuilder: (_, i) => ListTile(leading: const Icon(Icons.chat_bubble_outline), title: Text(_history[i].isNotEmpty ? _history[i][0].text : "Empty Chat", maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _loadHistory(i)))),
        ]),
      ),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Colors.black),
        title: DropdownButton<String>(value: _model, underline: const SizedBox(), items: const [DropdownMenuItem(value: "Gemini 1.5 Flash", child: Text("Gemini 1.5 Flash ▼", style: TextStyle(fontWeight: FontWeight.bold))), DropdownMenuItem(value: "Gemini 1.5 Pro", child: Text("Gemini 1.5 Pro ▼", style: TextStyle(fontWeight: FontWeight.bold)))], onChanged: (v) => setState(() => _model = v!)),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _newChat)],
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Image.asset("logo.png", height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, size: 80)), const SizedBox(height: 10), const Text("What can I help with?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Wrap(spacing: 8, children: ["Write a story", "Make a plan", "Explain AI", "Give ideas"].map((s) => ActionChip(label: Text(s), onPressed: () { _input.text = s; _send(); })).toList())])) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (_, i) { final m = _messages[i]; return Align(alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85), decoration: BoxDecoration(color: m.isUser ? Colors.green.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.text, style: const TextStyle(fontSize: 15)), if (!m.isUser) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () { Clipboard.setData(ClipboardData(text: m.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"))); }), IconButton(icon: const Icon(Icons.cloud_upload, size: 18), tooltip: 'Push to GitHub', onPressed: () => _showPushDialog(m.text)), IconButton(icon: const Icon(Icons.thumb_up, size: 16), onPressed: () {})])]))); })),
        if (_loading) const Padding(padding: EdgeInsets.all(8), child: Row(children: [CircularProgressIndicator(), SizedBox(width: 10), Text("AI is typing...")])),
        Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: _input, decoration: InputDecoration(hintText: "Ask anything...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)), onSubmitted: (_) => _send())), const SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.black, child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.white), onPressed: _send))])),
      ]),
    );
  }
}
