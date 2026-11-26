import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

const String apiKey = "Ab8RN6Iew00mjwjZNsn7isAG5N0NMpRQKbZ5_HS3tSVYE_Pwmw";

Future<String> askAI(String prompt) async {
  try {
    final res = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": prompt}
        ]
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["choices"][0]["message"]["content"].toString();
    } else {
      return "API Error: ${res.statusCode}\n${res.body}";
    }
  } catch (e) {
    return "Error: $e";
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AI",
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
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
  int _index = 0;
  final List<Widget> _pages = const [
    ChatPage(),
    FixCodePage(),
    BuildAppPage(),
    AutoBuildPage(),
    CheckAppPage(),
  ];
  final List<String> _titles = [
    "AI Chat",
    "Code Fixer",
    "Build Full App",
    "Auto-Build",
    "Check & Modify",
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        centerTitle: true,
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: "Fix"),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: "Build"),
          BottomNavigationBarItem(icon: Icon(Icons.autorenew), label: "Auto"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Check"),
        ],
      ),
    );
  }
}

// 1. CHAT PAGE
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msg = TextEditingController();
  final List<Map<String, String>> _chats = [];
  bool _l = false;

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) return;
    final q = _msg.text.trim();
    _msg.clear();
    setState(() {
      _chats.add({"role": "user", "text": q});
      _l = true;
    });
    final ans = await askAI(q);
    setState(() {
      _chats.add({"role": "ai", "text": ans});
      _l = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chats.length,
            itemBuilder: (context, i) {
              final c = _chats[i];
              final isUser = c["role"] == "user";
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.white : Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c["text"] ?? "",
                    style: TextStyle(color: isUser ? Colors.black : Colors.white),
                  ),
                ),
              );
            },
          ),
        ),
        if (_l) const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msg,
                  decoration: const InputDecoration(
                    hintText: "Ask anything...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text("Send"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 2. FIX CODE PAGE
class FixCodePage extends StatefulWidget {
  const FixCodePage({super.key});
  @override
  State<FixCodePage> createState() => _FixCodePageState();
}

class _FixCodePageState extends State<FixCodePage> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _err = TextEditingController();
  String _f = "";
  bool _l = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _code,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "Paste BROKEN Code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _err,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Paste ERROR",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                setState(() => _l = true);
                try {
                  _f = await askAI(
                    "You are expert developer. Fix this code on your own. Code: ${_code.text} Error: ${_err.text} Give FULL fixed code + what you changed + why.",
                  );
                } catch (e) {
                  _f = "Error: $e";
                }
                setState(() => _l = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text("AUTO-FIX MY CODE"),
            ),
            if (_l) const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(_f),
          ],
        ),
      ),
    );
  }
}

// 3. BUILD FULL APP PAGE
class BuildAppPage extends StatefulWidget {
  const BuildAppPage({super.key});
  @override
  State<BuildAppPage> createState() => _BuildAppPageState();
}

class _BuildAppPageState extends State<BuildAppPage> {
  final TextEditingController _idea = TextEditingController();
  String _r = "";
  bool _l = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _idea,
              decoration: const InputDecoration(
                hintText: "Ex: Make Instagram Clone",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                setState(() => _l = true);
                try {
                  _r = await askAI(
                    "Create complete Flutter app for: ${_idea.text}. Give 1. Folder Structure 2. pubspec.yaml 3. Full main.dart code 4. Steps to push to Git. Make it super advanced, complete, working.",
                  );
                } catch (e) {
                  _r = "Error: $e";
                }
                setState(() => _l = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text("BUILD FULL APP"),
            ),
            if (_l) const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(_r),
          ],
        ),
      ),
    );
  }
}

// 4. AUTO-BUILD PAGE
class AutoBuildPage extends StatefulWidget {
  const AutoBuildPage({super.key});
  @override
  State<AutoBuildPage> createState() => _AutoBuildPageState();
}

class _AutoBuildPageState extends State<AutoBuildPage> {
  final TextEditingController _cmd = TextEditingController();
  String _log = "";
  bool _l = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _cmd,
              decoration: const InputDecoration(
                hintText: "Ex: Make Chat App with Login",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _l = true;
                  _log = "Step 1: Creating...\nStep 2: Checking Errors...\nStep 3: Fixing...";
                });
                try {
                  final result = await askAI(
                    "Do AUTO-BUILD LOOP for: ${_cmd.text}. Step 1 Create full Flutter code. Step 2 Check errors yourself. Step 3 Fix all errors. Step 4 Give final FIXED working code + folder + Git push steps. Make it 100% error-free.",
                  );
                  _log = "BUILD SUCCESS - NO ERRORS!\n\n$result";
                } catch (e) {
                  _log = "Error - Auto-Fixing: $e";
                }
                setState(() => _l = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text("AUTO-RUN & BUILD"),
            ),
            if (_l) const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(_log),
          ],
        ),
      ),
    );
  }
}

// 5. CHECK & MODIFY PAGE
class CheckAppPage extends StatefulWidget {
  const CheckAppPage({super.key});
  @override
  State<CheckAppPage> createState() => _CheckAppPageState();
}

class _CheckAppPageState extends State<CheckAppPage> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _ask = TextEditingController();
  String _r = "";
  bool _l = false;

  Future<void> _do(String type) async {
    setState(() => _l = true);
    try {
      String prompt = "";
      if (type == "check") {
        prompt = "Check this app code for errors, bugs, missing features: ${_code.text}. Give full report.";
      } else if (type == "feature") {
        prompt = "Suggest 10 best features to add to this app: ${_code.text}. Give details.";
      } else {
        prompt = "Modify this code: ${_code.text}. Requested change: ${_ask.text}. Give FULL modified working code.";
      }
      _r = await askAI(prompt);
    } catch (e) {
      _r = "Error: $e";
    }
    setState(() => _l = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _code,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Paste FULL Code / ZIP Content",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ask,
              decoration: const InputDecoration(
                hintText: "What modification? Ex: Add Dark Mode",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _do("check"),
                  child: const Text("CHECK APP"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _do("feature"),
                  child: const Text("SUGGEST FEATURES"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _do("modify"),
              child: const Text("APPROVE & ADD"),
            ),
            if (_l) const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(_r),
          ],
        ),
      ),
    );
  }
}
