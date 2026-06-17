import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class SaveAudioScreen extends StatefulWidget {
  final String recordingPath;

  const SaveAudioScreen({super.key, required this.recordingPath});

  @override
  _SaveAudioScreenState createState() => _SaveAudioScreenState();
}

class _SaveAudioScreenState extends State<SaveAudioScreen> {
  final TextEditingController _audioNameController = TextEditingController();

  Future<void> _saveAudio() async {
    final String audioName = _audioNameController.text.trim();
    if (audioName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a name for the audio file.')),
      );
      return;
    }

    try {
      // Create saved recordings directory if it doesn't exist
      final savedDir =
          Directory('${path.dirname(widget.recordingPath)}/saved_recordings');
      if (!await savedDir.exists()) {
        await savedDir.create();
      }

      // Create new path with the user's name
      final newPath =
          '${savedDir.path}/$audioName${path.extension(widget.recordingPath)}';

      // Rename/move the file
      await File(widget.recordingPath).rename(newPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio saved as: $audioName')),
      );

      // Return to home screen
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving audio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Save Audio')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _audioNameController,
              decoration: InputDecoration(
                labelText: 'Audio Name',
                hintText: 'Enter a name for the audio file',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveAudio,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Save Audio'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
