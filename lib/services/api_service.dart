import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VoiceCloningService {
  static const String _baseUrl = 'http://192.168.100.9:5000';

  static Future<String> cloneVoice(String audioPath, String text) async {
    try {
      final file = File(audioPath);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('Uploading audio: $audioPath, Exists: $exists, Size: $size bytes');

      var request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/synthesize'));
      request.fields['text'] = text;
      request.files
          .add(await http.MultipartFile.fromPath('speaker', audioPath));
      print('Sending POST request to $_baseUrl/synthesize');

      var response = await request.send();
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final outputPath = '${directory.path}/cloned_audio.wav';
        final file = File(outputPath);
        await file.writeAsBytes(await response.stream.toBytes());
        print('Cloned audio saved at: $outputPath');
        return outputPath;
      } else {
        final error = await response.stream.bytesToString();
        print('Error response: $error');
        throw Exception(
            'Failed to clone voice: ${response.statusCode} - $error');
      }
    } catch (e) {
      print('Error cloning voice: $e');
      throw Exception('Error cloning voice: $e');
    }
  }
}
