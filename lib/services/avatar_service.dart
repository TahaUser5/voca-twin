import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AvatarService {
  /// A default fallback URL. The real URL will be loaded from SharedPreferences.
  static String _baseUrl = 'http://127.0.0.1:5000';

  /// Fetches the ngrok URL from local storage.
  static Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();

    /// Use the saved URL, or fall back to the default if not set.
    _baseUrl = prefs.getString('ngrok_url') ?? 'http://127.0.0.1:5000';
  }

  /// Exposes the current base URL for other parts of the app to use if needed.
  static String get baseUrl => _baseUrl;

  /// Generates an avatar by polling the server.
  /// Yields status strings and the final file path.
  static Stream<String> generateAvatar(
      String audioPath, String imagePath) async* {
    /// Load the latest URL from storage before starting.
    await _loadBaseUrl();

    yield "Uploading files...";

    int uploadAttempts = 0;
    while (true) {
      uploadAttempts++;
      try {
        /// Create a NEW request for each attempt to avoid "finalized" error.
        final startUri = Uri.parse('$_baseUrl/avatar');
        var request = http.MultipartRequest('POST', startUri);
        request.headers['Connection'] = 'close';

        /// Ensure fresh connection
        request.files
            .add(await http.MultipartFile.fromPath('audio', audioPath));
        request.files
            .add(await http.MultipartFile.fromPath('image', imagePath));

        final startResponse =
            await request.send().timeout(const Duration(seconds: 60));

        if (startResponse.statusCode == 202) {
          /// Success
          final responseBody = await startResponse.stream.bytesToString();
          final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
          final String? taskId = jsonResponse['task_id'];
          if (taskId == null) {
            throw Exception('Did not receive a task ID from the server.');
          }

          /// --- Hand off to polling logic ---
          yield* _pollForCompletion(taskId);

          /// Use yield* to delegate
          return;

          /// All done
        } else {
          /// Handle non-202 status codes
          if (uploadAttempts >= 3) {
            throw Exception(
                'Server returned status ${startResponse.statusCode} after 3 attempts.');
          }
          yield "Upload failed with status ${startResponse.statusCode} (attempt $uploadAttempts), retrying...";
          await Future.delayed(const Duration(seconds: 5));
        }
      } catch (e) {
        if (uploadAttempts >= 3) {
          throw Exception(
              'Failed to connect to server after $uploadAttempts attempts: $e');
        }
        yield "Upload failed (attempt $uploadAttempts), retrying...";
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  /// New private helper method to handle polling after successful upload.
  static Stream<String> _pollForCompletion(String taskId) async* {
    yield "Processing video... this may take several minutes.";
    while (true) {
      await Future.delayed(const Duration(seconds: 20));

      /// Wait before polling again
      try {
        final statusUri = Uri.parse('$_baseUrl/status/$taskId');
        final statusResponse = await http.get(statusUri, headers: {
          'Connection': 'close'
        }).timeout(const Duration(seconds: 30));

        if (statusResponse.statusCode != 200) {
          yield "Server status check failed with code ${statusResponse.statusCode}, retrying...";
          continue;
        }

        final statusJson = jsonDecode(statusResponse.body);
        final String status = statusJson['status'];
        yield "Server status: $status";

        if (status == 'completed') {
          yield "Downloading final video...";
          final resultUri = Uri.parse('$_baseUrl' + statusJson['result_url']);
          final resultResponse =
              await http.get(resultUri).timeout(const Duration(minutes: 5));

          if (resultResponse.statusCode != 200)
            throw Exception(
                'Download failed with status ${resultResponse.statusCode}');

          final bytes = resultResponse.bodyBytes;
          final dir = await getApplicationDocumentsDirectory();
          final outPath = '${dir.path}/avatar_${const Uuid().v4()}.mp4';
          final file = File(outPath);
          await file.writeAsBytes(bytes);

          yield outPath;
          return;
        } else if (status == 'failed') {
          final error = statusJson['error'] ?? 'Unknown server error';
          throw Exception('Avatar generation failed on server: $error');
        }
      } catch (e) {
        yield "Polling error: $e, retrying...";
        continue;
      }
    }
  }
}
