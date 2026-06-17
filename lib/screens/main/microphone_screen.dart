import 'package:flutter/material.dart';

class MicrophoneScreen extends StatelessWidget {
  const MicrophoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Microphone'),
      ),
      body: const Center(
        child: Text(
          'Microphone Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
