import 'package:flutter/material.dart';

class SaveAudioScreen extends StatefulWidget {
  final dynamic audioData; // Accept audio data

  const SaveAudioScreen({super.key, required this.audioData});

  @override
  _SaveAudioScreenState createState() => _SaveAudioScreenState();
}

class _SaveAudioScreenState extends State<SaveAudioScreen> {
  final TextEditingController _audioNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _audioNameController.dispose();
    super.dispose();
  }

  void _saveAudio() {
    if (_formKey.currentState!.validate()) {
      String audioName = _audioNameController.text.trim();

      // Simulate saving the audio file
      print("Saving Audio: $audioName with data: ${widget.audioData}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio saved as: $audioName')),
      );

      _audioNameController.clear();
      Navigator.pop(context); // Return to the previous screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const SizedBox(height: 50),
            // Logo at the top
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
                        'Save Audio',
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
                            hintText: 'Enter audio name',
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
                              return 'Please enter a name for the audio file.';
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
                            onPressed: () => Navigator.pop(context),
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
                            onPressed: _saveAudio,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F3CFA),
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
