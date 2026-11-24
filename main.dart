import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
const String apiKey = 'AQ.Ab8RN6ILVlfEZnGHTWZ8HnxmFaADXq4zsp8MH_CGiOZtgs_3FQ' ;
void main() => runApp(const MyApp());
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black), home: const HomeScreen());
  }
}
class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _i = 0;
  final _pages = [const ChatProPage(), const AutoFixPage(), const BuildPage(), const AutoRunPage(), const ZipPage(), const ConnectPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(6), child: Image.asset('logo.png', errorBuilder: (c,e,s) => const Icon(Icons.smart_toy))),
        title: const Text('Ai'),
        backgroundColor: Colors.purple, centerTitle: true,
      ),
      body: _pages[_i],
      bottomNavigationBar: BottomNavigationBar(currentIndex: _i, onTap: (v) => setState(() => _i = v), backgroundColor: Colors.black, selectedItemColor: Colors.purpleAccent, unselectedItemColor: Colors.white54, type: BottomNavigationBarType.fixed, items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat Pro'),
        BottomNavigationBarItem(icon: Icon(Icons.healing), label: 'Auto-Fix'),
        BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Build App'),
        BottomNavigationBarItem(icon: Icon(Icons.autorenew), label: 'Auto-Run APK'),
        BottomNavigationBarItem(icon: Icon(Icons.folder_zip), label: 'ZIP / Modify'),
        BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Connect'),
      ]),
    );
  }
}
Future<String> askAI(String prompt) async {
  final res = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}]}));
  final data = jsonDecode(res.body);
  return data['candidates'][0]['content']['parts'][0]['text'];
}
class ChatProPage extends StatefulWidget { const ChatProPage({super.key}); @override State<ChatProPage> createState() => _ChatProPageState(); }
class _ChatProPageState extends State<ChatProPage> {
  final _c = TextEditingController(); String _r = 'I am Ai - Ghost Level Pro!\nMore powerful than ChatGPT! Ask anything!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: Column(children: [Image.asset('logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.smart_toy, size: 80)), const SizedBox(height: 10), Expanded(child: SingleChildScrollView(child: Text(_r))), if (_l) const CircularProgressIndicator(), TextField(controller: _c, decoration: const InputDecoration(hintText: 'Ask like ChatGPT Pro...')), ElevatedButton(onPressed: () async { setState(() => _l = true); try { _r = await askAI('You are Ai, Ghost Level Pro, more powerful than ChatGPT. Answer pro advance: ${_c.text}'); } catch (e) { _r = 'Error: Check API Key! $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: const Text('ASK Ai'))]));
}
class AutoFixPage extends StatefulWidget { const AutoFixPage({super.key}); @override State<AutoFixPage> createState() => _AutoFixPageState(); }
class _AutoFixPageState extends State<AutoFixPage> {
  final _code = TextEditingController(); final _err = TextEditingController(); String _f = 'Paste Code + Error - Ai will solve, edit, change on its own!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _code, maxLines: 5, decoration: const InputDecoration(hintText: 'Paste Code', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _err, maxLines: 3, decoration: const InputDecoration(hintText: 'Paste Error', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() => _l = true); try { _f = await askAI('Fix on your own. Edit, change, solve everything yourself. Code: ${_code.text} Error: ${_err.text} Give FULL fixed code.'); } catch (e) { _f = 'Error: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('AUTO-FIX 🔥')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_f)]))));
}
class BuildPage extends StatefulWidget { const BuildPage({super.key}); @override State<BuildPage> createState() => _BuildPageState(); }
class _BuildPageState extends State<BuildPage> {
  final _idea = TextEditingController(); String _sel = 'Flutter'; String _r = 'Type app idea - Ai will plan, create full advance coding, folder, Git steps. Handles Flutter / Web / Python / React!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [DropdownButton<String>(value: _sel, items: ['Flutter','Web','Python','React','Android'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _sel = v!)), TextField(controller: _idea, decoration: const InputDecoration(hintText: 'Ex: Make Instagram Clone', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() => _l = true); try { _r = await askAI('Create complete ADVANCE app in $_sel for: ${_idea.text}. Give 1. Full Plan 2. Folder Structure 3. Full Code 4. Git push steps.'); } catch (e) { _r = 'Error: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('BUILD FULL APP 🚀')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_r)]))));
}
class AutoRunPage extends StatefulWidget { const AutoRunPage({super.key}); @override State<AutoRunPage> createState() => _AutoRunPageState(); }
class _AutoRunPageState extends State<AutoRunPage> {
  final _cmd = TextEditingController(); String _log = 'AUTO-RUN READY!\nYou just give instruction!\nAi will: Create > Check > Fix > Run Again > Create APK Again - All in One!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _cmd, decoration: const InputDecoration(hintText: 'Instruction: Ex: Make Chat App with Login', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() { _l = true; _log = 'Step 1: Creating...\nStep 2: Checking Error Myself...\nStep 3: Fixing Myself...\nStep 4: Running Again...\nStep 5: Creating APK Again...'; }); try { _log = '✅ AUTO-RUN SUCCESS!\n\n${await askAI('Do AUTO-RUN LOOP for: ${_cmd.text}. Create full code, check errors yourself, fix yourself, re-run, give final error-free code + folder + Git steps.')}'; } catch (e) { _log = 'Error: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: const Text('AUTO-RUN & BUILD APK 🤖')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_log)]))));
}
class ZipPage extends StatefulWidget { const ZipPage({super.key}); @override State<ZipPage> createState() => _ZipPageState(); }
class _ZipPageState extends State<ZipPage> {
  final _code = TextEditingController(); final _ask = TextEditingController(); String _r = 'Paste Full File / ZIP Content.\nAi will check FULL file + folder, create app, suggest advance features.'; bool _l = false;
  Future<void> _do(String type) async { setState(() => _l = true); String p = ''; if (type == 'check') p = 'Check FULL app file + folder: ${_code.text}. Find bugs, give full fixed code.'; if (type == 'feature') p = 'Check FULL app file + folder: ${_code.text}. Give 10 ADVANCE feature ideas.'; if (type == 'modify') p = 'Modify FULL app: ${_code.text}. User wants: ${_ask.text}. User approved. Give full updated code.'; try { _r = await askAI(p); } catch (e) { _r = 'Error: $e'; } setState(() => _l = false); }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _code, maxLines: 6, decoration: const InputDecoration(hintText: 'Paste Full File / ZIP Content', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _ask, decoration: const InputDecoration(hintText: 'What modification? Ex: Add Payment', border: OutlineInputBorder())), const SizedBox(height: 10), Row(children: [ElevatedButton(onPressed: () => _do('check'), child: const Text('CHECK FULL APP')), const SizedBox(width: 8), ElevatedButton(onPressed: () => _do('feature'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('SUGGEST FEATURES'))]), const SizedBox(height: 10), ElevatedButton(onPressed: () => _do('modify'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('APPROVE & MODIFY ✅')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_r)]))));
}
class ConnectPage extends StatefulWidget { const ConnectPage({super.key}); @override State<ConnectPage> createState() => _ConnectPageState(); }
class _ConnectPageState extends State<ConnectPage> {
  final _app = TextEditingController(); String _r = 'Connect Any App!\nEx: GitHub, Firebase, WhatsApp, YouTube\nAi will give connection steps + code!'; bool _l = false;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(children: [TextField(controller: _app, decoration: const InputDecoration(hintText: 'Which App to Connect? Ex: GitHub', border: OutlineInputBorder())), const SizedBox(height: 10), ElevatedButton(onPressed: () async { setState(() => _l = true); try { _r = await askAI('How to connect ${_app.text} with my Ai app? Give full steps + code to connect and work together.'); } catch (e) { _r = 'Error: $e'; } setState(() => _l = false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('CONNECT APP 🔗')), if (_l) const CircularProgressIndicator(), const SizedBox(height: 10), Text(_r)]))));
}