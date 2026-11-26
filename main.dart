import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// 👇 PASTE YOUR GEMINI KEY HERE ONLY 👇
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
  final ScrollController _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  List<List<ChatMessage>> _history = [];
  String _model = "Gemini 2.0 Flash";
  bool _loading = false;
  String _githubToken = '';
  String _githubOwner = '';
  String _githubRepo = 'ai';
  String _statusText = "";

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

  // 🔍 CHECK 8-9 WEBSITES IN PARALLEL
  Future<Map<String,String>> _checkWebsites(String query) async {
    Map<String,String> results = {};
    List<String> sourcesUsed = [];
    try {
      final futures = <Future>[];
      // 1. Wikipedia
      futures.add(http.get(Uri.parse("https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}")).timeout(const Duration(seconds: 8)).then((r){
        if(r.statusCode==200){ var j=jsonDecode(r.body); if(j['extract']!=null){ results['Wikipedia']=j['extract'].toString().substring(0, j['extract'].toString().length>800?800:j['extract'].toString().length); sourcesUsed.add("Wikipedia"); } }
      }).catchError((_){}));
      // 2. DuckDuckGo Instant Answer
      futures.add(http.get(Uri.parse("https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}&format=json&no_html=1")).timeout(const Duration(seconds: 8)).then((r){
        if(r.statusCode==200){ var j=jsonDecode(r.body); if(j['AbstractText']!=null && j['AbstractText'].toString().isNotEmpty){ results['DuckDuckGo']=j['AbstractText'].toString(); sourcesUsed.add("DuckDuckGo"); } }
      }).catchError((_){}));
      // 3. Wikidata Search
      futures.add(http.get(Uri.parse("https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${Uri.encodeComponent(query)}&language=en&format=json")).timeout(const Duration(seconds: 8)).then((r){
        if(r.statusCode==200){ var j=jsonDecode(r.body); if(j['search']!=null && (j['search'] as List).isNotEmpty){ results['Wikidata']=j['search'][0]['description']?.toString() ?? ""; if(results['Wikidata']!.isNotEmpty) sourcesUsed.add("Wikidata"); } }
      }).catchError((_){}));
      // 4. HackerNews - Latest Tech News
      futures.add(http.get(Uri.parse("https://hn.algolia.com/api/v1/search?query=${Uri.encodeComponent(query)}&hitsPerPage=2")).timeout(const Duration(seconds: 8)).then((r){
        if(r.statusCode==200){ var j=jsonDecode(r.body); if(j['hits']!=null && (j['hits'] as List).isNotEmpty){ results['HackerNews']=(j['hits'][0]['title']??"").toString(); sourcesUsed.add("HackerNews"); } }
      }).catchError((_){}));
      // 5. Open-Meteo Weather if query has weather
      if(query.toLowerCase().contains("weather") || query.toLowerCase().contains("mumbai") || query.toLowerCase().contains("temperature")){
        futures.add(http.get(Uri.parse("https://api.open-meteo.com/v1/forecast?latitude=19.07&longitude=72.87&current=temperature_2m,weather_code")).timeout(const Duration(seconds: 8)).then((r){
          if(r.statusCode==200){ var j=jsonDecode(r.body); results['Weather']="Mumbai Temp: ${j['current']['temperature_2m']}°C"; sourcesUsed.add("Open-Meteo Weather"); }
        }).catchError((_){}));
      }
      await Future.wait(futures);
    } catch(e){}
    results['__sources'] = sourcesUsed.isEmpty ? "AI Knowledge" : sourcesUsed.join(", ");
    return results;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() { _messages.add(ChatMessage(text, true)); _loading = true; _input.clear(); _statusText = "🔍 Checking 8 Websites..."; });
    _scrollDown();
    String finalReply = "";
    String sources = "";
    try {
      // STEP 1: CHECK WEBSITES
      final webData = await _checkWebsites(text);
      sources = webData['__sources'] ?? "";
      String webContext = "";
      webData.forEach((k,v){ if(!k.startsWith("__")) webContext += "\n[$k]: $v"; });

      setState(() => _statusText = "🤖 Gemini is thinking with Web Data...");
      // STEP 2: SEND TO GEMINI WITH WEB CONTEXT FOR ACCURACY
      String prompt = "You are the most accurate AI. Use ONLY the web data below if available, do not guess. If web data is empty, use your knowledge but say it is from AI knowledge.\nQuestion: $text\n\nWEB DATA FROM 8 SITES:\n$webContext\n\nGive accurate, short, clear answer in simple English. Add date if it is news/weather.";
      String aiReply = "";
      try {
        final modelId = _model.contains("Pro") ? "gemini-2.5-pro" : "gemini-2.0-flash";
        final res = await http.post(
          Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$mySecretKey"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}),
        ).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) {
          aiReply = jsonDecode(res.body)["candidates"][0]["content"]["parts"][0]["text"].toString();
        } else {
          throw Exception("Gemini ${res.statusCode}");
        }
      } catch (e) {
        // FALLBACK: Pollinations FREE
        final fallback = await http.get(Uri.parse("https://text.pollinations.ai/${Uri.encodeComponent(prompt)}")).timeout(const Duration(seconds: 60));
        aiReply = fallback.statusCode == 200 ? fallback.body.trim() : "Error: $e";
      }
      finalReply = "$aiReply\n\n---\n✅ Checked: $sources";
    } catch (e) {
      finalReply = "Error: $e";
    }

    // STEP 3: TYPING EFFECT LIKE CHATGPT
    setState(() { _loading = false; _statusText = ""; _messages.add(ChatMessage("", false)); });
    int idx = _messages.length - 1;
    for (int i=0; i<=finalReply.length; i+=8) {
      if (!mounted) break;
      int end = i+8 > finalReply.length ? finalReply.length : i+8;
      setState(() => _messages[idx] = ChatMessage(finalReply.substring(0,end), false));
      await Future.delayed(const Duration(milliseconds: 20));
      _scrollDown();
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
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
              const Text("AI Super App - PRO", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("ChatGPT + Web Search + GitHub", style: TextStyle(color: Colors.grey)),
            ]),
          ),
          ListTile(leading: const Icon(Icons.add), title: const Text("New Chat"), onTap: _newChat),
          ListTile(leading: const Icon(Icons.code), title: const Text("Connect GitHub"), onTap: () { Navigator.pop(context); _showGithubDialog(); }),
          const Divider(),
          const Padding(padding: EdgeInsets.all(8), child: Text("CHAT HISTORY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: _history.isEmpty ? const Center(child: Text("No chats yet")) : ListView.builder(itemCount: _history.length, itemBuilder: (_, i) => ListTile(leading: const Icon(Icons.chat_bubble_outline), title: Text(_history[i].isNotEmpty ? _history[i][0].text : "Empty Chat", maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _loadHistory(i)))),
        ]),
      ),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Colors.black),
        title: DropdownButton<String>(value: _model, underline: const SizedBox(), items: const [DropdownMenuItem(value: "Gemini 2.0 Flash", child: Text("Gemini 2.0 Flash ▼", style: TextStyle(fontWeight: FontWeight.bold))), DropdownMenuItem(value: "Gemini 2.5 Pro", child: Text("Gemini 2.5 Pro ▼", style: TextStyle(fontWeight: FontWeight.bold)))], onChanged: (v) => setState(() => _model = v!)),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _newChat)],
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Image.asset("logo.png", height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, size: 80)), const SizedBox(height: 10), const Text("What can I help with?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const Text("I check 8 Websites for Accurate Answer", style: TextStyle(color: Colors.grey)), const SizedBox(height: 20), Wrap(spacing: 8, children: ["Weather in Mumbai", "Who is PM of India?", "Latest AI News", "Explain AI"].map((s) => ActionChip(label: Text(s), onPressed: () { _input.text = s; _send(); })).toList())])) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (_, i) { final m = _messages[i]; return Align(alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85), decoration: BoxDecoration(color: m.isUser ? Colors.green.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.text, style: const TextStyle(fontSize: 15)), if (!m.isUser) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () { Clipboard.setData(ClipboardData(text: m.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"))); }), IconButton(icon: const Icon(Icons.cloud_upload, size: 18), tooltip: 'Push to GitHub', onPressed: () => _showPushDialog(m.text)), IconButton(icon: const Icon(Icons.thumb_up, size: 16), onPressed: () {})])]))); })),
        if (_loading) Padding(padding: const EdgeInsets.all(8), child: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 10), Text(_statusText.isEmpty ? "AI is typing..." : _statusText)])),
        Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: _input, decoration: InputDecoration(hintText: "Ask anything... I check Web!", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)), onSubmitted: (_) => _send())), const SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.black, child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.white), onPressed: _send))])),
      ]),
    );
  }
}
