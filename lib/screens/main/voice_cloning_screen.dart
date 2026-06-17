import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
// import 'package:flutter_sound/ui/sound_recorder_ui.dart'; // REMOVED BAD IMPORT
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:math' as math;

// --- Make sure these imports point to your actual files ---
import '../../widgets/custom_bottom_navbar.dart';
import 'save_audio_screen.dart';
import 'synthesize_screen.dart';
import 'audio_added_screen.dart';
import '../../services/voice_cloning_service.dart';

class VoiceCloningScreen extends StatefulWidget {
  const VoiceCloningScreen({Key? key}) : super(key: key);

  @override
  State<VoiceCloningScreen> createState() => _VoiceCloningScreenState();
}

class _VoiceCloningScreenState extends State<VoiceCloningScreen> {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _isLoading = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  String? _audioFilePath;
  StreamSubscription? _recorderSubscription;
  double _dbLevel = 0.0;

  final String _promptText = '''
"Hello, my name is Alex, and I'm excited to create my voice agent today. Can you please tell me the weather forecast for tomorrow? I'd like to order a coffee with two sugars and no milk. What's the latest news in technology this week? Thank you for helping me out. Have a great day! How long will it take to travel from New York to Los Angeles? Can you set a reminder for my meeting at 10 a.m. tomorrow? Play my favorite playlist for me, please. What are the top-rated restaurants nearby? Can you explain how the voice agent works in simple terms?"
  ''';

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndInit();
  }

  Future<void> _requestPermissionsAndInit() async {
    // Request microphone permission
    final micStatus = await Permission.microphone.request();

    if (micStatus.isPermanentlyDenied) {
      // If permanently denied, guide user to settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
                'Microphone permission is permanently denied. Please enable it in app settings.'),
            actions: [
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (micStatus.isDenied) {
      // If denied (but not permanently), show a SnackBar and return
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record audio.'),
          ),
        );
      }
      return;
    }

    // If granted, proceed
    await _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();

    // Listen to the recorder's progress
    _recorderSubscription = _recorder.onProgress!.listen((e) {
      if (e.decibels != null) {
        setState(() {
          _dbLevel = e.decibels!;
        });
      }
    });

    setState(() {
      _isRecorderInitialized = true;
    });
    print('Recorder initialized.');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorderSubscription?.cancel(); // Cancel subscription on dispose
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
    }
    super.dispose();
  }

  Future<String> _getRecordingPath() async {
    Directory directory;
    if (Platform.isAndroid) {
      // Try saving to public Music folder so file managers can see it
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        directory = dirs.first;
      } else {
        // Fallback to the app's private documents directory if Music is unavailable
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      // For iOS and other platforms
      directory = await getApplicationDocumentsDirectory();
    }
    final ext = Platform.isAndroid ? 'aac' : 'wav';
    // Construct filename in chosen directory
    final path =
        '${directory.path}/voice_sample_${DateTime.now().millisecondsSinceEpoch}.$ext';
    print('Unified recording path set to: $path');
    return path;
  }

  Future<bool> _requestMicAndStoragePermission() async {
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final micReq = await Permission.microphone.request();
      if (!micReq.isGranted) return false;
    }
    return true;
  }

  void _startRecording() async {
    if (!_isRecorderInitialized) return;
    final allowed = await _requestMicAndStoragePermission();
    if (!allowed) {
      print('Microphone permission not granted.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Microphone permission is required. Please grant it in app settings.'),
            action:
                SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
      }
      return;
    }

    await _recorder.setSubscriptionDuration(
      const Duration(milliseconds: 100),
    );

    final path = await _getRecordingPath();
    print('Starting recording to: $path');
    await _recorder.startRecorder(
      toFile: path,
      codec: Platform.isAndroid ? Codec.aacMP4 : Codec.pcm16WAV,
      audioSource: AudioSource.microphone,
    );
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _audioFilePath = path;
      _elapsedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 30) {
          _stopRecording();
        }
      });
    });
    print('Recording started.');
  }

  void _stopRecording() async {
    if (!_isRecording && !_isPaused) return;
    _timer?.cancel();
    final path = await _recorder.stopRecorder();
    print('Recording stopped.');
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isFinished = true;
      _audioFilePath = path;
      _dbLevel = 0.0;
    });
    if (path != null) {
      final file = File(path);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('Audio saved at: $path, Exists: $exists, Size: $size bytes');
    }
  }

  void _restartRecording() {
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isFinished = false;
      _isRecording = false;
      _isPaused = false;
      _audioFilePath = null;
      _dbLevel = 0.0;
    });
    print("Recording restarted.");
  }

  void _togglePauseResume() async {
    if (!_isRecording && !_isPaused) return;

    if (_isPaused) {
      await _recorder.resumeRecorder();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _elapsedSeconds++);
      });
      print("Recording resumed.");
    } else {
      _timer?.cancel();
      await _recorder.pauseRecorder();
      print("Recording paused.");
    }

    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _sendToFlaskBackend(String text, String audioPath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(audioPath);
      final exists = await file.exists();
      if (!exists || await file.length() <= 44) {
        print("Aborting send to backend: Audio file is empty or invalid.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot proceed, recording is empty.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      print(
          'Sending audio file: $audioPath, Size: ${await file.length()} bytes');

      final clonedAudioPath =
          await VoiceCloningService.cloneVoice(audioPath, text);
      print('Cloned audio received at: $clonedAudioPath');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice cloned successfully!')),
      );

      // Play back the synthesized audio
      final player = FlutterSoundPlayer();
      await player.openPlayer();
      await player.startPlayer(
        fromURI: clonedAudioPath,
        codec: Codec.pcm16WAV,
        whenFinished: () async {
          await player.closePlayer();
        },
      );
    } catch (e) {
      print('Error cloning voice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cloning voice: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(1, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$remainingSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E00AC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Record Voice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _isRecording ? _stopRecording : _startRecording,
        backgroundColor: _isRecording ? Colors.red : const Color(0xFF1B2BA4),
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(_isRecording ? Icons.stop : Icons.mic,
            color: Colors.white, size: 30),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0,
        onItemSelected: (int index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/profile_settings');
          }
        },
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Speak Conversationally",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B2BA4)),
                          ),
                          const SizedBox(height: 15),
                          Column(
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _togglePauseResume,
                                    child: Icon(
                                      _isRecording && !_isPaused
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      color: const Color(0xFF1B2BA4),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 50,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: AudioVisualizer(
                                        dbLevel: _dbLevel,
                                        isRecording: _isRecording,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.circle,
                                      color: Colors.red, size: 10),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${_formatDuration(_elapsedSeconds)}/0:30",
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "— Or Read the text below —",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 200, // Fixed height to prevent overflow
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _promptText.trim(),
                                style: const TextStyle(
                                    fontSize: 14.5, height: 1.5),
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    _isFinished ? _restartRecording : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B2BA4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(100, 40),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.refresh,
                                    color: Colors.white, size: 20),
                                label: const Text(
                                  "Restart",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isFinished && _audioFilePath != null
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AudioAddedScreen(
                                                    audioPath: _audioFilePath!,
                                                  )),
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(100, 40),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.cloud_upload,
                                    color: Colors.white, size: 20),
                                label: const Text(
                                  "Clone Voice",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.5),
              child: Center(
                child: SpinKitFadingCircle(
                  color: Colors.blue[900],
                  size: 50.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AudioVisualizer extends StatefulWidget {
  final double dbLevel;
  final bool isRecording;
  final int barCount;

  const AudioVisualizer({
    Key? key,
    required this.dbLevel,
    required this.isRecording,
    this.barCount = 30,
  }) : super(key: key);

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> {
  Timer? _animationTimer;
  double _animationValue = 0.0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    _animationTimer?.cancel();
    if (widget.isRecording) {
      _animationTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
          setState(() {
            _animationValue += 0.2;
          });
        }
      });
    }
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    if (mounted) {
      setState(() {
        _animationValue = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Normalize dbLevel: -60 (silence) to 0 (max).
    final normalized = (widget.dbLevel.clamp(-60.0, 0.0) + 60.0) / 60.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.barCount, (index) {
        if (!widget.isRecording) {
          // Static bars when not recording
          return Container(
            width: 3.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(5),
            ),
          );
        }

        // Animated bars when recording
        final waveOffset = (_animationValue + index * 0.3) % (2 * math.pi);
        final dynamicHeight = (normalized * 20.0) +
            (10.0 * (0.5 + 0.5 * math.sin(waveOffset))) +
            (5.0 * (index.isEven ? 1 : 0.7));

        return Container(
          width: 3.0,
          height: dynamicHeight.clamp(4.0, 35.0),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}
