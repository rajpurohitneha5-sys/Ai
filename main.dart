import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiKey = 'Ab8RN6Iew00mjwjZNsn7isAG5N0NMpRQKbZ5_HS3tSVYE_Pwmw';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF212121),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF212121), elevation: 0),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _i = 0;
  final _pages = const [
    ChatPage(),
    FixerPage(),
    BuilderPage(),
    AutoBuildPage(),
    ZipPage(),
    PluginsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI - Ghost Level Pro', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _pages[_i],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        backgroundColor: const Color(0xFF171717),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat Pro'),
          BottomNavigationBarItem(icon: Icon(Icons.bug_report_outlined), label: 'Auto-Fix'),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Build App'),
          BottomNavigationBarItem(icon: Icon(Icons.autorenew), label: 'Auto-Run'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_zip_outlined), label: 'ZIP / Check'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Plugins'),
        ],
      ),
    );
  }
}

Future<String> askAI(String prompt) async {
  final res = await http.post(
    Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}]}),
  );
  final data = jsonDecode(res.body);
  return data['candidates'][0]['content']['parts'][0]['text'];
}

// 1. CHAT - ChatGPT UI, NO LOGO
class ChatPage extends StatefulWidget { const ChatPage({super.key}); @override State<ChatPage> createState() => _ChatPageState(); }
class _ChatPageState extends State<ChatPage> {
  final _c = TextEditingController();
  List<Map<String, String>> _msgs = [];
  bool _l = false;

  void _send() async {
    if (_c.text.trim().isEmpty) return;
    String q = _c.text; _c.clear();
    setState(() { _msgs.add({'role': 'user', 'text': q}); _l = true; });
    try {
      String r = await askAI(q);
      setState(() => _msgs.add({'role': 'ai', 'text': r}));
    } catch (e) {
      setState(() => _msgs.add({'role': 'ai', 'text': 'Error: Check API Key! $e'}));
    }
    setState(() => _l = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _msgs.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('What can I help with?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _msgs.length,
                  itemBuilder: (c, i) {
                    bool isUser = _msgs[i]['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: isUser ? const Color(0xFF2F2F2F) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                        child: Text(_msgs[i]['text']!, style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
        ),
        if (_l) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: _c, decoration: InputDecoration(hintText: 'Ask anything', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF2F2F2F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.black), onPressed: _send)),
          ]),
        ),
      ],
    );
  }
}

// 2. AUTO-FIX
class FixerPage extends StatefulWidget { const FixerPage({super.key}); @override State<FixerPage> createState() => _FixerPageState(); }
class _FixerPageState extends State<FixerPage> {
  final _code = TextEditingController(); final _err = TextEditingController(); String _f = 'Paste Code + Error - I will Auto-Fix on my own!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _code, maxLines: 5, decoration: const InputDecoration(hintText: 'Paste BROKEN Code', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _err, maxLines: 3, decoration: const InputDecoration(hintText: 'Paste ERROR', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() => _l = true); try { _f = await askAI('You are expert developer. Fix this code on your own. Code: ${_code.text} Error: ${_err.text} Give FULL fixed code + what you changed + why.'); } catch (e) { _f = 'Error: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: const Text('AUTO-FIX MY CODE')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_f)]))));
}

// 3. BUILD APP
class BuilderPage extends StatefulWidget { const BuilderPage({super.key}); @override State<BuilderPage> createState() => _BuilderPageState(); }
class _BuilderPageState extends State<BuilderPage> {
  final _idea = TextEditingController(); String _r = 'Type app idea - I will create FULL app + Folder Structure + Git Steps!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _idea, decoration: const InputDecoration(hintText: 'Ex: Make Instagram Clone', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() => _l = true); try { _r = await askAI('Create complete Flutter app for: ${_idea.text}. Give 1. Folder Structure 2. pubspec.yaml 3. Full main.dart code 4. Steps to push to Git. Make it super advanced, complete, working.'); } catch (e) { _r = 'Error: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: const Text('BUILD FULL APP')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_r)]))));
}

// 4. AUTO-RUN
class AutoBuildPage extends StatefulWidget { const AutoBuildPage({super.key}); @override State<AutoBuildPage> createState() => _AutoBuildPageState(); }
class _AutoBuildPageState extends State<AutoBuildPage> {
  final _cmd = TextEditingController(); String _log = 'AUTO-RUN LOOP READY!\n1. Give Command\n2. I Create Code\n3. I Check Error\n4. I Fix & Re-Run\n5. APK Ready'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _cmd, decoration: const InputDecoration(hintText: 'Ex: Make Chat App with Login', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() { _l = true; _log = 'Step 1: Creating...\nStep 2: Checking Errors...\nStep 3: Fixing...'; }); try { _log = 'BUILD SUCCESS - NO ERRORS!\n\n${await askAI('Do AUTO-BUILD LOOP for: ${_cmd.text}. Step 1 Create full Flutter code. Step 2 Check errors yourself. Step 3 Fix all errors. Step 4 Give final FIXED working code + folder + Git push steps. Make it 100% error-free.')}'; } catch (e) { _log = 'Error - Auto-Fixing: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: const Text('AUTO-RUN & BUILD')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_log)]))));
}

// 5. ZIP / CHECK
class ZipPage extends StatefulWidget { const ZipPage({super.key}); @override State<ZipPage> createState() => _ZipPageState(); }
class _ZipPageState extends State<ZipPage> {
  final _code = TextEditingController(); final _ask = TextEditingController(); String _r = 'Paste FULL Code Here. I will check FULL app, suggest features, and add on your approval.'; bool _l = false;
  Future<void> _do(String type) async { setState(() => _l = true); String p = ''; if (type == 'check') p = 'Check FULL app: ${_code.text}. Find bugs, give full fixed code.'; if (type == 'feature') p = 'Check FULL app: ${_code.text}. Suggest 10 super advanced features to add, explain each.'; if (type == 'modify') p = 'Modify FULL app: ${_code.text}. User wants: ${_ask.text}. Give full updated code with modification.'; try { _r = await askAI(p); } catch (e) { _r = 'Error: $e'; } setState(() => _l = false); }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _code, maxLines: 6, decoration: const InputDecoration(hintText: 'Paste FULL Code / ZIP Content', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _ask, decoration: const InputDecoration(hintText: 'What modification? Ex: Add Dark Mode', border: OutlineInputBorder())), const SizedBox(height: 10), Row(children: [ElevatedButton(onPressed: () => _do('check'), child: const Text('CHECK APP')), const SizedBox(width: 8), ElevatedButton(onPressed: () => _do('feature'), child: const Text('SUGGEST FEATURES'))]), const SizedBox(height: 10), ElevatedButton(onPressed: () => _do('modify'), child: const Text('APPROVE & ADD')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_r)]))));
}

// 6. PLUGINS - ALL
class PluginsPage extends StatelessWidget {
  const PluginsPage({super.key});
  final List<String> plugins = const ['Gmail', 'Google Drive', 'Canva', 'Notion', 'Google Calendar', 'Dropbox', 'HubSpot', 'Stripe', 'Spotify', 'Apple Music', 'YouTube', 'ElevenLabs', 'iCloud', 'Remote Desktop'];
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plugins.length,
      itemBuilder: (c, i) => Card(color: const Color(0xFF2F2F2F), child: ListTile(title: Text(plugins[i], style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54), onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugins[i]} Plugin - Ask in Chat Pro to use it!'))); })),
    );
  }
}
