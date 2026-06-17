import 'package:flutter/material.dart';
import 'package:voca_twin/services/chatbot_service.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final Duration? responseTime;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.responseTime,
  });

  ChatMessage.loading()
      : text = '',
        isUser = false,
        isLoading = true,
        responseTime = null;
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // Initial suggestion buttons
  List<String> _suggestions = [
    'How to use VocaTwin APP?',
    'How to Clone My Avatar?',
    'How to Clone the Voice?',
  ];
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    // When the user manually sends a message, clear suggestion buttons
    setState(() {
      _suggestions.clear();
      // Show user message and a loading indicator
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage.loading());
    });
    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start(); // Start timing the response

    try {
      final reply = await ChatbotService.sendMessage(text);
      stopwatch.stop(); // Stop timing

      setState(() {
        // Remove loading indicator
        final idx = _messages.indexWhere((m) => m.isLoading);
        if (idx != -1) _messages.removeAt(idx);
        // Add bot reply with response time
        _messages.add(ChatMessage(
          text: reply,
          isUser: false,
          responseTime: stopwatch.elapsed,
        ));
      });
    } catch (e) {
      stopwatch.stop(); // Also stop on error
      setState(() {
        final idx = _messages.indexWhere((m) => m.isLoading);
        if (idx != -1) _messages.removeAt(idx);
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E00AC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'VocaTwinBot',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Chat message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: msg.isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: msg.isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!msg.isUser) ...[
                            CircleAvatar(
                              backgroundColor: const Color(0xFF2F3FA8),
                              child: const Text('VB',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: msg.isUser
                                      ? const Color(0xFF2F3FA8)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: msg.isLoading
                                    ? const SpinKitThreeBounce(
                                        color: Color(0xFF2F3FA8),
                                        size: 20.0,
                                      )
                                    : Text(msg.text,
                                        style: TextStyle(
                                            color: msg.isUser
                                                ? Colors.white
                                                : Colors.black87)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Display "Replying in" for loading messages (bottom left)
                      if (!msg.isUser && msg.isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(
                                  width: 56), // Space for avatar + gap
                              Text(
                                'Replying in',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Display response time for completed bot messages (bottom right)
                      if (!msg.isUser &&
                          !msg.isLoading &&
                          msg.responseTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${(msg.responseTime!.inMilliseconds / 1000).toStringAsFixed(1)}s',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(
                                  width: 8), // Small margin from edge
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Suggestions near input
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _suggestions.map((s) {
                  return ElevatedButton(
                    onPressed: () => setState(() {
                      _textController.text = s;
                      _suggestions.clear();
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F3FA8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                    ),
                    child: Text(
                      s,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                    ),
                    onChanged: (value) {
                      if (_suggestions.isNotEmpty)
                        setState(() => _suggestions.clear());
                    },
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2F3FA8)),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
