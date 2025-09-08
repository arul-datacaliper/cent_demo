import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: "👋 Welcome! I'm your AIT Coach Bot.\nLet’s make your allergy therapy smooth and successful. 💪",
      isBot: true,
    ),
  ];
  bool _showInput = false;
  final _controller = TextEditingController();

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
          text: "Allergy Immunotherapy (AIT) is a treatment that helps your body build tolerance to allergens over time. "
                "It involves regular exposure to small amounts of allergens, usually through injections or drops, to reduce symptoms and improve quality of life. "
                "\n\nBenefits:\n• Long-term relief\n• Reduced medication need\n• Improved daily functioning\n\nAsk your provider for more details about your specific therapy plan.",
          isBot: true,
        ));
      });
    } else if (label.contains('Side Effects')) {
      setState(() {
        _messages.add(_ChatMessage(
          text: "Common side effects of AIT include mild redness, swelling, or itching at the injection site. "
                "Some people may experience sneezing or mild allergy symptoms after treatment. "
                "\n\nWhat’s Normal:\n• Mild local reactions\n• Temporary symptoms\n\nContact your provider if you experience severe reactions such as difficulty breathing, hives, or swelling of the face/throat.",
          isBot: true,
        ));
      });
    }
    // Add more handlers as needed
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _controller.clear();
      _showInput = false;
      // Optionally, add bot response here
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isBot ? Colors.blue[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(msg.text, style: const TextStyle(fontSize: 16)),
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

class _ChatMessage {
  final String text;
  final bool isBot;
  _ChatMessage({required this.text, required this.isBot});
}