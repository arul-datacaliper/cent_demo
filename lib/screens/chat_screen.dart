import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  String text;
  final bool isBot;
  List<Map<String, dynamic>>? citations; // [{id,title,url?}]
  List<String>? followUps;
  bool streaming; // true while tokens are arriving
  _ChatMessage({
    required this.text,
    required this.isBot,
    this.citations,
    this.followUps,
    this.streaming = false,
  });
}

class _ChatScreenState extends State<ChatScreen> {

 // static const String _baseUrl = 'http://localhost:5230';
  //static const String _baseUrl = 'http://10.0.2.2:5230';
  static const String _baseUrl = 'https://stage-fortifyguardian-api-bbf0cxa5bjc6bjay.eastus-01.azurewebsites.net';



  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: "👋 Welcome! I'm your AIT Coach Bot.\nLet’s make your allergy therapy smooth and successful. 💪",
      isBot: true,
    ),
  ];
  bool _showInput = false;
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  StreamSubscription<String>? _streamSub;
  final _client = http.Client();

  @override
  void dispose() {
    _streamSub?.cancel();
    _client.close();
    _scrollCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleOption(String label) {
    if (label.contains('Ask a Question')) {
      setState(() {
        _messages.add(_ChatMessage(
          text: "What would you like to ask?",
          isBot: true,
        ));
        _showInput = true;
      });
    } else if (label.contains('Learn About AIT')) {
      setState(() {
        _messages.add(_ChatMessage(
          text:
              "Allergy Immunotherapy (AIT) helps your body build tolerance to allergens over time. "
              "It can reduce symptoms and medication needs.\n\nBenefits:\n• Long-term relief\n• Reduced meds\n• Better daily life",
          isBot: true,
        ));
      });
    } else if (label.contains('Side Effects')) {
      setState(() {
        _messages.add(_ChatMessage(
          text:
              "Common side effects: mild redness/swelling/itching at injection site, mild sneezing. "
              "Contact your provider for severe reactions (trouble breathing, hives, facial/throat swelling).",
          isBot: true,
        ));
      });
    }
    _autoScroll();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _controller.clear();
      _showInput = false;
    });
    _autoScroll();

    // Start streaming bot answer
    await _startStreamingAnswer(text);
  }

  Future<void> _startStreamingAnswer(String prompt) async {
    // Cancel any previous stream
    await _streamSub?.cancel();

    // Add a new (empty) bot bubble in streaming mode
    setState(() {
      _messages.add(_ChatMessage(text: "", isBot: true, streaming: true));
    });
    final int botIndex = _messages.length - 1;
    _autoScroll();
    


    final req = http.Request('POST', Uri.parse('$_baseUrl/chat/ask'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        "message": prompt,
        "topK": 5,
        "stream": true,
      });

    final streamed = await _client.send(req);

    // The API emits "data: {json}\n\n" lines (SSE). We'll split by line.
    _streamSub = streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!line.startsWith('data:')) return;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') return;

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return;
      }

      final type = payload['type'];
      if (type == 'token') {
        final token = (payload['text'] ?? '') as String;
        if (token.isEmpty) return;
        setState(() {
          _messages[botIndex].text += token; // append token
        });
        _autoScroll();
      } else if (type == 'final') {
        setState(() {
          _messages[botIndex].streaming = false;
          _messages[botIndex].citations =
              (payload['citations'] as List?)?.cast<Map<String, dynamic>>();
          _messages[botIndex].followUps =
              (payload['followUps'] as List?)?.cast<String>();
        });
        _autoScroll();
      } else if (type == 'error') {
        setState(() {
          _messages[botIndex].streaming = false;
          _messages[botIndex].text =
              _messages[botIndex].text.isEmpty ? 'Something went wrong.' : _messages[botIndex].text;
        });
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _messages[botIndex].streaming = false;
        if (_messages[botIndex].text.isEmpty) {
          _messages[botIndex].text = 'Network error. Please try again.';
        }
      });
    }, onDone: () {
      if (!mounted) return;
      setState(() {
        _messages[botIndex].streaming = false;
      });
    });
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIT Coach Bot'),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _messages.length,
                itemBuilder: (_, i) => _chatBubble(_messages[i]),
              ),
            ),
            if (!_showInput)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _optionButton(context, "1️⃣ Ask a Question"),
                  _optionButton(context, "2️⃣ View My Schedule"),
                  _optionButton(context, "3️⃣ Learn About AIT"),
                  _optionButton(context, "4️⃣ Side Effects & What’s Normal"),
                  _optionButton(context, "5️⃣ Insurance or Billing Questions"),
                ],
              ),
            if (_showInput)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Type your question...",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.grey),
                    tooltip: "Back to Menu",
                    onPressed: () {
                      setState(() => _showInput = false);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chatBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isBot ? Colors.blue[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              msg.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(msg.text, style: const TextStyle(fontSize: 16)),
            if (msg.streaming) ...[
              const SizedBox(height: 8),
              const _TypingDots(),
            ],
            if ((msg.citations?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: msg.citations!
                    .map((c) => Chip(
                          label: Text(c['title'] ?? c['id'] ?? 'Source'),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF0d6efd)),
                        ))
                    .toList(),
              )
            ],
            if ((msg.followUps?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: msg.followUps!
                    .map((q) => OutlinedButton(
                          onPressed: () {
                            // Send follow-up as the next question
                            setState(() {
                              _messages.add(_ChatMessage(text: q, isBot: false));
                            });
                            _startStreamingAnswer(q);
                          },
                          child: Text(q),
                        ))
                    .toList(),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _optionButton(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue[700],
          elevation: 0,
          side: const BorderSide(color: Color(0xFF0d6efd)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () => _handleOption(label),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = (_c.value * 3).floor();
        final dots = '.' * (t + 1);
        return Text('typing$dots', style: TextStyle(color: Colors.blue[600]));
      },
    );
  }
}
