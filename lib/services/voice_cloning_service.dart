import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;

class VoiceCloningService {
  // Update this URL to match where your voice clone backend is running
  static const String _baseUrl = 'http://localhost:5000';

  static Future<String> cloneVoice(String audioPath, String text) async {
    try {
      final file = File(audioPath);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('Uploading audio: $audioPath, Exists: $exists, Size: $size bytes');

      if (!exists || size == 0) {
        throw Exception('Audio file does not exist or is empty.');
      }

      final baseUrl = _baseUrl;
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/synthesize'));
      request.fields['text'] = text;
      request.files
          .add(await http.MultipartFile.fromPath('speaker', audioPath));
      print('Sending POST request to $baseUrl/synthesize');

      late http.StreamedResponse response;
      try {
        response = await request.send();
      } on SocketException catch (e) {
        print('Network error sending to $baseUrl: $e');
        throw Exception(
            'Cannot connect to backend at $baseUrl. Please ensure the server is running and accessible.');
      }
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        if (bytes.isEmpty) {
          throw Exception('Received empty audio file from server.');
        }

        final appDocDir =
            await path_provider.getApplicationDocumentsDirectory();
        // Create a dedicated directory for cloned voices
        final clonedVoicesDir = Directory('${appDocDir.path}/cloned_voices');
        if (!await clonedVoicesDir.exists()) {
          await clonedVoicesDir.create(recursive: true);
        }

        // --- Start of new logic for sequential naming ---
        int nextFileNumber = 1;
        // Use listSync as the number of files isn't expected to be huge
        final existingFiles = clonedVoicesDir
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .where((fileName) =>
                fileName.startsWith('cloned_voice_') &&
                fileName.endsWith('.wav'))
            .toList();

        if (existingFiles.isNotEmpty) {
          final fileNumbers = existingFiles
              .map((fileName) {
                final match =
                    RegExp(r'cloned_voice_(\d+)\.wav').firstMatch(fileName);
                if (match != null && match.group(1) != null) {
                  return int.tryParse(match.group(1)!);
                }
                return null;
              })
              .where((number) => number != null)
              .cast<int>()
              .toList();

          if (fileNumbers.isNotEmpty) {
            fileNumbers.sort();
            nextFileNumber = fileNumbers.last + 1;
          }
        }
        // --- End of new logic for sequential naming ---

        // Save with a sequential filename
        final fileName = 'cloned_voice_$nextFileNumber.wav';
        final outputPath = '${clonedVoicesDir.path}/$fileName';
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(bytes);
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
