import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import '../../services/avatar_service.dart';
import 'avatar_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../widgets/custom_bottom_navbar.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart'; // Comment this out

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({Key? key}) : super(key: key);

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  String? _selectedAudioPath;
  String? _imagePath;
  List<File> _clonedVoices = [];
  bool _isGenerating = false;
  String _generationStatus = '';
  String? _finalVideoPath;
  // Progress tracking
  double _progress = 0.0;
  int _progressPercentage = 0;
  // Animation state
  bool _showImageCheck = false;
  bool _hasUserSelectedVoice = false; // Track if user manually selected a voice
  // Countdown logic
  static const int _maxGenerationTimeInSeconds = 600; // 10 minutes
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadClonedVoices();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _animateProgressTo(double targetProgress) {
    _progressTimer?.cancel();

    const duration = Duration(milliseconds: 50);
    const step = 0.01; // 1% per step

    _progressTimer = Timer.periodic(duration, (timer) {
      if (_progress < targetProgress) {
        setState(() {
          _progress = (_progress + step).clamp(0.0, targetProgress);
          _progressPercentage = (_progress * 100).round();
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadClonedVoices() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final clonedVoicesDir = Directory('${appDocDir.path}/cloned_voices');

      if (await clonedVoicesDir.exists()) {
        final files = clonedVoicesDir
        .listSync()
        .whereType<File>()
            .where((f) => f.path.endsWith('.wav'))
        .toList();
        // Sort by modification date, newest first
        files.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        setState(() {
          _clonedVoices = files;
          // Auto-select the first voice if available
          if (_clonedVoices.isNotEmpty) {
            _selectedAudioPath = _clonedVoices.first.path;
          }
        });
      }
    } catch (e) {
      // Handle potential errors, e.g., permissions
      debugPrint("Error loading cloned voices: $e");
    }
  }

  Future<void> _pickAudioFile() async {
    // This function is no longer needed as we use the dropdown.
    // Kept for reference or future use if needed.
  }

  Future<void> _chooseSavedVoice() async {
    // This function is also replaced by the dropdown.
  }

  Future<bool> _isHumanFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint("Error processing image for face detection: $e");
      return false;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final isHuman = await _isHumanFace(picked.path);

    if (!isHuman) {
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
      // Clear the image path if it's not a human face
      setState(() {
        _imagePath = null;
      });
      return;
    }

    // Existing logic to handle jpg/jpeg conversion to png
    final ext = p.extension(picked.path).toLowerCase();
    String finalPath = picked.path;
    if (ext == '.jpg' || ext == '.jpeg') {
      final bytes = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final pngBytes = img.encodePng(decoded);
        final dir = await getTemporaryDirectory();
        final base =
            p.basenameWithoutExtension(picked.name).replaceAll(' ', '_');
        final pngFile = File('${dir.path}/$base.png');
        await pngFile.writeAsBytes(pngBytes);
        finalPath = pngFile.path;
      }
    }
    setState(() {
      _imagePath = finalPath;
      _showImageCheck = true; // Show the check animation
    });

    // Hide the check after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showImageCheck = false;
        });
      }
    });
  }

  Future<void> _generateAndShowAvatar() async {
    if (_imagePath == null || _selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both an audio and image file.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationStatus = 'Starting...';
      _progress = 0.0;
      _progressPercentage = 0;
    });

    try {
      final stream =
          AvatarService.generateAvatar(_selectedAudioPath!, _imagePath!);

      await for (final statusOrResult in stream) {
        if (statusOrResult.contains('/')) {
          // Save the source image for the virtual meeting feature
          await _saveAvatarSourceImage(_imagePath!);

          // Set progress to 100% when completed
          setState(() {
            _progress = 1.0;
            _progressPercentage = 100;
            _generationStatus = 'Generation completed!';
          });

          await Future.delayed(const Duration(seconds: 1));

          // This setState call is what rebuilds the UI
          setState(() {
            _finalVideoPath = statusOrResult;
            _isGenerating = false;
          });

          // Navigate to AvatarScreen after a short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.push(
              context,
            MaterialPageRoute(
                builder: (context) => AvatarScreen(videoPath: statusOrResult),
            ),
          );
          }
        } else {
          // Handle status updates from the service with gradual progress
          final progressMatch =
              RegExp(r'Progress: (\d+)%').firstMatch(statusOrResult);
          if (progressMatch != null) {
            final progressValue = int.tryParse(progressMatch.group(1)!) ?? 0;

            // Gradually increase progress to avoid sudden jumps
            final targetProgress = progressValue / 100.0;
            _animateProgressTo(targetProgress);

            setState(() {
              _generationStatus = 'Generating... $progressValue%';
            });
          } else {
          setState(() {
            _generationStatus = statusOrResult;
          });
          }
        }
      }
    } catch (e) {
        setState(() {
          _isGenerating = false;
        _generationStatus = 'Error: ${e.toString()}';
        });
    }
  }

  Future<void> _saveAvatarSourceImage(String imagePath) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final savedAvatarsDir =
          Directory('${appDocDir.path}/saved_avatars_sources');
      if (!await savedAvatarsDir.exists()) {
        await savedAvatarsDir.create(recursive: true);
      }
      final fileName = p.basename(imagePath);
      await File(imagePath).copy('${savedAvatarsDir.path}/$fileName');
      debugPrint(
          'Avatar source image saved to ${savedAvatarsDir.path}/$fileName');
    } catch (e) {
      debugPrint('Failed to save avatar source image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload your Avatar'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E00AC),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload Your Voice',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildVoiceDropdown()),
                const SizedBox(width: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: _selectedAudioPath != null && _hasUserSelectedVoice
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 32,
                          key: ValueKey('selected'),
                        )
                      : const SizedBox(
                          width: 32, // To prevent layout jump
                          key: ValueKey('not_selected'),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Upload Your Picture',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildImagePicker(),
            const SizedBox(height: 40),
            if (_isGenerating)
              _buildGenerationProgress()
            else
              ElevatedButton(
                onPressed: _generateAndShowAvatar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E00AC),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Generate Avatar',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            // Removed "View Avatar" section as per user request
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1, // Corresponds to the 'Avatar' or 'Scan' page
        onItemSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            // Already on a page related to settings/profile action, do nothing or navigate to main settings
            Navigator.pushReplacementNamed(context, '/profile_settings');
          }
        },
      ),
    );
  }

  Widget _buildVoiceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAudioPath,
          isExpanded: true,
          hint: const Text('Select a cloned voice'),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2E00AC)),
          items: _clonedVoices.map((file) {
            return DropdownMenuItem<String>(
              value: file.path,
            child: Text(
                p.basename(file.path),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedAudioPath = value;
              _hasUserSelectedVoice = true; // Mark that user manually selected
            });
          },
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
            decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
        ),
        child: _imagePath == null
            ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 60, color: Colors.grey.shade500),
                  const SizedBox(height: 10),
                  const Text('Tap to select an image'),
                ],
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  // Animated checkmark overlay
                  AnimatedOpacity(
                    opacity: _showImageCheck ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 60,
                      ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildGenerationProgress() {
    // Calculate remaining time based on progress
    final remainingSeconds =
        (_maxGenerationTimeInSeconds * (1.0 - _progress)).round();
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    final remainingTime = '$minutes:$seconds';

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E00AC).withOpacity(0.1),
            const Color(0xFF4242DC).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2E00AC).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E00AC).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar generation icon with animation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E00AC), Color(0xFF4242DC)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E00AC).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 6.28, // 2π for full rotation
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 32,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Status text with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF2E00AC), Color(0xFF4242DC)],
            ).createShader(bounds),
            child: Text(
              _generationStatus,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // Creative progress bar with glow effect
          Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E00AC).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  // Background
                  Container(
                    width: double.infinity,
              decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),
              ),
                  // Animated progress fill
                  AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                    width: MediaQuery.of(context).size.width * 0.8 * _progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2E00AC),
                          const Color(0xFF4242DC),
                          const Color(0xFF6A5AE0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4242DC).withOpacity(0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  // Animated shimmer effect
                  if (_progress > 0)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedBuilder(
                          animation: AlwaysStoppedAnimation(1.0),
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Progress percentage with animated counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E00AC).withOpacity(0.1),
                      const Color(0xFF4242DC).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2E00AC).withOpacity(0.3),
                  ),
                ),
                child: TweenAnimationBuilder(
                  tween: IntTween(begin: 0, end: _progressPercentage),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Text(
                      '$value%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E00AC),
                      ),
                    );
                  },
                ),
              ),

              // Countdown timer with icon
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.1),
                      Colors.red.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: AlwaysStoppedAnimation(1.0),
                      builder: (context, child) {
                        return const Icon(
                          Icons.access_time,
                          color: Colors.orange,
                          size: 18,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      remainingTime,
                      style: const TextStyle(
                        fontSize: 16,
                  fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Process steps indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProcessStep(
                icon: Icons.face_retouching_natural,
                label: 'Face Analysis',
                isActive: _progressPercentage >= 0,
                isCompleted: _progressPercentage > 25,
              ),
              _buildProcessStep(
                icon: Icons.graphic_eq,
                label: 'Voice Processing',
                isActive: _progressPercentage >= 25,
                isCompleted: _progressPercentage > 50,
              ),
              _buildProcessStep(
                icon: Icons.video_library,
                label: 'Avatar Generation',
                isActive: _progressPercentage >= 50,
                isCompleted: _progressPercentage > 75,
              ),
              _buildProcessStep(
                icon: Icons.check_circle,
                label: 'Finalizing',
                isActive: _progressPercentage >= 75,
                isCompleted: _progressPercentage >= 100,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: isCompleted
                ? const LinearGradient(
                    colors: [Colors.green, Color(0xFF4CAF50)],
                  )
                : isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF2E00AC), Color(0xFF4242DC)],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.grey.shade300,
                          Colors.grey.shade400,
                        ],
                      ),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: isCompleted
                          ? Colors.green.withOpacity(0.4)
                          : const Color(0xFF2E00AC).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF2E00AC) : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
