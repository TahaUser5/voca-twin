import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  // Update this URL to match where your chatbot backend is running
  static const String _baseUrl = 'http://localhost:5001';

  /// Sends [prompt] to the backend chat endpoint and returns the reply.
  static Future<String> sendMessage(String prompt) async {
    final uri = Uri.parse('$_baseUrl/chat');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': prompt}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('message')) {
        return data['message'] as String;
      } else if (data.containsKey('error')) {
        throw Exception('Chatbot error: \\${data['error']}');
      } else {
        throw Exception('Unexpected response: \\${response.body}');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: \\${response.reasonPhrase}');
    }
  }
} 