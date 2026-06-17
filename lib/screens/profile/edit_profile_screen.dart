import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voca_twin/screens/main/welcome_screen.dart';
import 'package:path_provider/path_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String? email;
  const ProfileSetupScreen({super.key, this.email});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String? _selectedImagePath;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;
  late final TextEditingController _dobController;
  DateTime? _selectedDate;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController(text: widget.email);
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
    _dobController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _dobController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  /// Copies a temporary picked image into documents to persist it across restarts
  Future<String> _copyToDocuments(String tempPath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final fileName = tempPath.split('/').last;
    final newPath = '${docDir.path}/$fileName';
    final copied = await File(tempPath).copy(newPath);
    return copied.path;
  }

  Future<bool> _isHumanFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Face> faces = await _faceDetector.processImage(inputImage);
    return faces.isNotEmpty;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final isHuman = await _isHumanFace(pickedFile.path);

      if (isHuman) {
        final permPath = await _copyToDocuments(pickedFile.path);
        setState(() {
          _selectedImagePath = permPath;
        });
      } else {
        setState(() {
          _selectedImagePath = null;
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invalid Image'),
              content: const Text('Please select a proper human image.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  /// Opens a date picker dialog and sets the selected date in the controller
  Future<void> _selectDate() async {
    final firstDate = DateTime(1990);
    final lastDate = DateTime.now();
    final initial = _selectedDate ?? firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      // no selectableDayPredicate
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text =
            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade300,
                          image: _selectedImagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(_selectedImagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImagePath == null
                            ? const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 40,
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _pickImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "ADD PHOTO",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Username Input
                buildInputField(
                  "Username",
                  "Enter your username",
                  Icons.person,
                  controller: _usernameController,
                ),

                // Email Input
                buildInputField(
                  "Email Address",
                  "Enter your email",
                  Icons.email,
                  controller: _emailController,
                ),

                // Password Input
                buildInputField(
                  "Password",
                  "Enter your password",
                  Icons.lock,
                  obscureText: true,
                  controller: _passwordController,
                ),

                // Confirm Password Input
                buildInputField(
                  "Confirm Password",
                  "Re-enter your password",
                  Icons.lock,
                  obscureText: true,
                  controller: _confirmController,
                ),

                // Date of Birth Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _dobController,
                          decoration: InputDecoration(
                            hintText: 'MM/DD/YYYY',
                            prefixIcon:
                                Icon(Icons.calendar_today, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[900]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[900]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[900]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final userName = _usernameController.text;
                      await prefs.setBool(
                          'is_logged_in', true); // Mark user as logged in
                      await prefs.setString('user_name', userName);
                      await prefs.setString(
                          'user_email', _emailController.text);
                      if (_selectedImagePath != null) {
                        await prefs.setString(
                            'user_image_path', _selectedImagePath!);
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WelcomeScreen(
                            imagePath: _selectedImagePath,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "SUBMIT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable Text Field Widget with selective blue styling
  Widget buildInputField(String label, String hint, IconData icon,
      {bool obscureText = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900], // Blue heading only
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.black), // Default text color
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey), // Grey hint text
              prefixIcon: Icon(icon, color: Colors.grey), // Grey icon
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[900]!), // Blue border
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[900]!), // Blue border
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[900]!), // Blue border
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}
