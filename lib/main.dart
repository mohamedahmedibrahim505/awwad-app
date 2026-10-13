import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
const String modelName = 'gemini-2.5-flash';

const String userPrompt =
    'أنت "عواد"، مساعد ذكاء اصطناعي مصري ظريف وودود. ترد بلهجة مصرية شعبية خفيفة الدم، وبإجابات قصيرة وواضحة، وتنادي المستخدم "يا باشا".';
const String adminPrompt =
    'أنت "عواد" في وضع المدير. رد بأسلوب جاد ومنظم ومفصل بدون هزار، وبنفس اللهجة المصرية.';

void main() => runApp(const AwwadApp());

class AwwadApp extends StatelessWidget {
  const AwwadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عواد AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const ChatPage(),
    );
  }
}

class Msg {
  final String role;
  final String text;
  Msg(this.role, this.text);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Msg> _msgs = [
    Msg('model', 'منور يا باشا، أنا عواد معاك وجاهز لأي أمر!')
  ];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _loading = false;
  bool _admin = false;

  Future<String> _ask() async {
    if (apiKey.isEmpty) throw Exception('المفتاح ناقص');
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent');
    final history = _msgs.skipWhile((m) => m.role == 'model').map((m) => {
          'role': m.role,
          'parts': [
            {'text': m.text}
          ]
        }).toList();
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _admin ? adminPrompt : userPrompt}
        ]
      },
      'contents': history,
    });
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _msgs.add(Msg('user', text));
      _loading = true;
      _ctrl.clear();
    });
    _toBottom();
    String reply;
    try {
      reply = await _ask();
    } catch (e) {
      reply = 'ما قدرت أرد هلأ، جرّب مرة ثانية ($e)';
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(Msg('model', reply));
      _loading = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عواد AI',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _admin = !_admin),
            child: Text(_admin ? 'وضع المدير' : 'وضع المستخدم'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (context, i) {
                final m = _msgs[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(m.text,
                        style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('عواد عم يكتب...',
                  style: TextStyle(color: Colors.grey)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
