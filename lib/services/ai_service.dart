import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static final String? _apiKey = dotenv.env['GEMINI_API_KEY'];

  static Future<String> getResponse(String prompt) async {
    if (_apiKey == null || _apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('API key not found. Please set it in your .env file.');
    }

    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey!);
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        return response.text!;
      } else {
        throw Exception('Failed to get a response from the AI.');
      }
    } catch (e) {
      // Log the specific error for debugging
      print('Error communicating with AI Service: $e');
      throw Exception('Could not get response from AI: ${e.toString()}');
    }
  }
}
