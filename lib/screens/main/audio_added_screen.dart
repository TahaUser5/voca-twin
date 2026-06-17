import 'dart:io';
import 'package:flutter/material.dart';
import 'audio_selection_screen.dart';

class AudioAddedScreen extends StatefulWidget {
  final String audioPath;
  const AudioAddedScreen({Key? key, required this.audioPath}) : super(key: key);

  @override
  _AudioAddedScreenState createState() => _AudioAddedScreenState();
}

class _AudioAddedScreenState extends State<AudioAddedScreen> {
  final _audioNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-fill with filename without extension
    final name = widget.audioPath.split(Platform.pathSeparator).last;
    _audioNameController.text = name.replaceAll(RegExp(r'\.wav?\$'), '');
  }

  @override
  void dispose() {
    _audioNameController.dispose();
    super.dispose();
  }

  void _onCancel() {
    // Go back without saving
    Navigator.pop(context);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final newName = _audioNameController.text.trim();
    final original = File(widget.audioPath);
    final directory = original.parent;
    final newPath = '${directory.path}${Platform.pathSeparator}$newName.wav';
    try {
      await original.rename(newPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio saved as: $newName.wav')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AudioSelectionScreen(audioDirectory: directory.path),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2F3CFA);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const SizedBox(height: 50),
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Save Recording',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B2BA4),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _audioNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter recording name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a name for the recording.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _onCancel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 35,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 35,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 