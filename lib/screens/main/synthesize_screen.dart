import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/voice_cloning_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

class SynthesizeScreen extends StatefulWidget {
  final String audioSamplePath;
  const SynthesizeScreen({Key? key, required this.audioSamplePath})
      : super(key: key);

  @override
  State<SynthesizeScreen> createState() => _SynthesizeScreenState();
}

class _SynthesizeScreenState extends State<SynthesizeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _isCloning = false;
  bool _isSuccess = false;
  String? _clonedAudioPath;
  double _progress = 0.0;

  // Countdown Logic
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  static const int _maxCloningTime = 60; // 60 seconds max
  Duration? _completionTime; // Store total completion time

  // Animation
  late AnimationController _animationController;
  late AnimationController
      _successAnimationController; // For success animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _successPulseAnimation; // For success pulse

  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // Listen for duration and position updates
    _audioPlayer!.durationStream.listen((d) {
      if (d != null) setState(() => _audioDuration = d);
    });
    _audioPlayer!.positionStream.listen((p) {
      setState(() => _audioPosition = p);
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Success animation controller
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Subtle pulsing animation for professional look
    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Success pulse animation
    _successPulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    ));

    // Gentle scale animation
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _animationController.dispose();
    _successAnimationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _resetState() {
    setState(() {
      _isCloning = false;
      _isSuccess = false;
      _clonedAudioPath = null;
      _progress = 0.0;
      _remainingSeconds = 0;
      _completionTime = null;
      _textController.clear();
    });
    _successAnimationController.reset();
  }

  Future<void> _cloneVoice() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text to synthesize.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!mounted) return;

    final stopwatch = Stopwatch()..start(); // Track total completion time

    setState(() {
      _isCloning = true;
      _isSuccess = false;
      _remainingSeconds = _maxCloningTime;
      _progress = 0.0;
      _completionTime = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _progress = 1.0 - (_remainingSeconds / _maxCloningTime);
        } else {
          _progress = 0.95; // Show almost complete if timer runs out
          timer.cancel();
        }
      });
    });

    try {
      final outputPath = await VoiceCloningService.cloneVoice(
        widget.audioSamplePath,
        text,
      );
      stopwatch.stop(); // Stop timing
      _clonedAudioPath = outputPath;
      if (!mounted) return;
      setState(() {
        _isCloning = false;
        _isSuccess = true;
        _progress = 1.0;
        _completionTime = stopwatch.elapsed;
      });

      // Trigger success animation
      _successAnimationController.forward();

      // Prepare audio player
      try {
        await _audioPlayer?.setFilePath(outputPath);
      } catch (_) {}
      _countdownTimer?.cancel();
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
      // When an error occurs, stop cloning and reset progress.
      setState(() {
        _isCloning = false;
        _progress = 0.0;
      });
      _countdownTimer?.cancel();
    }
  }

  Future<void> _downloadClonedVoice() async {
    if (_clonedAudioPath == null) return;

    // Request storage permission, which is managed differently by OS.
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Storage permission is required to save the file.')),
        );
      }
      return;
    }

    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // This gets the primary external storage directory (e.g., /storage/emulated/0)
        // We will save into a "Download" subfolder, which is standard.
        downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir != null) {
          final downloadPath = Directory('${downloadsDir.path}/Download');
          if (!await downloadPath.exists()) {
            await downloadPath.create(recursive: true);
          }
          downloadsDir = downloadPath;
        }
      } else if (Platform.isIOS) {
        // On iOS, saves to the app's documents directory, accessible via Files app.
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not find a suitable directory for saving.');
      }

      final sourceFile = File(_clonedAudioPath!);
      final fileName = p.basename(_clonedAudioPath!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'VocaTwin_${timestamp}_$fileName';
      final newPath = p.join(downloadsDir.path, newFileName);

      await sourceFile.copy(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File saved to Downloads as $newFileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5061CC);

    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final remainingTime = '$minutes:$seconds';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E00AC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
        title: const Text(
          'Text to Speech',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _successPulseAnimation]),
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isSuccess
                          ? Colors.green
                          : _isCloning
                              ? Color.lerp(
                                  primaryColor,
                                  primaryColor.withOpacity(0.7),
                                  _pulseAnimation.value)!
                              : Colors.grey.shade300,
                      width: _isSuccess ? 3 : 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isSuccess
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 10 * _successPulseAnimation.value,
                              spreadRadius: 2 * _successPulseAnimation.value,
                            )
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _textController,
                    expands: true,
                    maxLines: null,
                    readOnly: _isCloning || _isSuccess,
                    decoration: InputDecoration(
                      hintText: 'Enter text to synthesize...',
                      filled: true,
                      fillColor: _isSuccess
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isCloning || _isSuccess) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 22,
                            valueColor: _isSuccess
                                ? AlwaysStoppedAnimation<Color>(Color.lerp(
                                    Colors.green,
                                    Colors.green.shade300,
                                    _successPulseAnimation.value)!)
                                : _isCloning
                                    ? AlwaysStoppedAnimation<Color>(Color.lerp(
                                        primaryColor,
                                        primaryColor.withOpacity(0.7),
                                        _pulseAnimation.value,
                                      )!)
                                    : const AlwaysStoppedAnimation<Color>(
                                        Colors.grey),
                            backgroundColor: Colors.grey[300],
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Show countdown during cloning, completion time after success
                  if (_isCloning)
                    Text(
                      'Time Remaining: $remainingTime',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  if (_isSuccess)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          // Large green checkmark for completion
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.green.shade200, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8 * _successPulseAnimation.value,
                                  spreadRadius:
                                      1 * _successPulseAnimation.value,
                                )
                              ],
                            ),
                            child: Transform.scale(
                              scale: _successPulseAnimation.value,
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Successfully Cloned!',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_completionTime != null)
                            Text(
                              'Completed in ${(_completionTime!.inMilliseconds / 1000).toStringAsFixed(1)}s',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 20),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? Colors.green
                          : _isCloning
                              ? Color.lerp(
                                  primaryColor,
                                  primaryColor.withOpacity(0.7),
                                  _pulseAnimation.value,
                                )!
                              : primaryColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ElevatedButton(
                      onPressed:
                          (_isCloning || _isSuccess) ? null : _cloneVoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _isSuccess
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Successfully Cloned',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              )
                            : _isCloning
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Cloning...',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  )
                                : const Text('Clone Your Voice',
                                    style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                if (_isSuccess) ...[
                  const SizedBox(height: 20),
                  // Rich audio playback UI
                  if (_clonedAudioPath != null) ...[
                    // Playback position slider
                    Slider(
                      min: 0.0,
                      max: _audioDuration.inMilliseconds.toDouble(),
                      value: _audioPosition.inMilliseconds
                          .clamp(0, _audioDuration.inMilliseconds)
                          .toDouble(),
                      onChanged: (value) {
                        _audioPlayer
                            ?.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    // Rewind, Play/Pause, Forward controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10,
                              size: 36, color: Colors.green),
                          onPressed: () {
                            final newPos =
                                _audioPosition - const Duration(seconds: 10);
                            _audioPlayer?.seek(newPos > Duration.zero
                                ? newPos
                                : Duration.zero);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isAudioPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 48,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            if (_isAudioPlaying) {
                              await _audioPlayer?.pause();
                            } else {
                              await _audioPlayer?.play();
                            }
                            setState(() => _isAudioPlaying = !_isAudioPlaying);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10,
                              size: 36, color: Colors.green),
                          onPressed: () {
                            final newPos =
                                _audioPosition + const Duration(seconds: 10);
                            _audioPlayer?.seek(newPos < _audioDuration
                                ? newPos
                                : _audioDuration);
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _resetState,
                    icon: const Icon(Icons.replay),
                    label: const Text('Start Over'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color(0xFF5E35B1),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF5E35B1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}
