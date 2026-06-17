import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';

class SaveAudioScreen extends StatefulWidget {
  const SaveAudioScreen({super.key});

  @override
  State<SaveAudioScreen> createState() => _SaveAudioScreenState();
}

class _SaveAudioScreenState extends State<SaveAudioScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;

  Future<void> _startRecording() async {
    final tempDir = await getTemporaryDirectory();
    final filePath = "${tempDir.path}/recorded_audio.wav";
    await _recorder.startRecorder(toFile: filePath);
    setState(() {
      _isRecording = true;
      _recordedFilePath = filePath;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> sendToVoiceCloningBackend(String text, String audioPath) async {
    final String backendUrl = "http://<your-flask-backend-url>/clone_and_tts";

    final audioFile = File(audioPath);
    final request = http.MultipartRequest("POST", Uri.parse(backendUrl))
      ..fields['text'] = text
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final bytes = await response.stream.toBytes();
      final tempDir = await getTemporaryDirectory();
      final ttsPath = "${tempDir.path}/tts_output.wav";
      final ttsFile = File(ttsPath);
      await ttsFile.writeAsBytes(bytes);

      final player = FlutterSoundPlayer();
      await player.openPlayer();
      await player.startPlayer(fromURI: ttsFile.path);
    } else {
      throw Exception("Voice cloning backend failed with status ${response.statusCode}");
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save Audio'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _recordedFilePath != null
                  ? () async {
                      try {
                        const String sampleText = "Hello, this is a test.";
                        await sendToVoiceCloningBackend(sampleText, _recordedFilePath!);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      }
                    }
                  : null,
              child: const Text('Send to Voice Cloning Backend'),
            ),
          ],
        ),
      ),
    );
  }
}