import 'dart:io';
import 'package:flutter/material.dart';
import 'synthesize_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class AudioSelectionScreen extends StatefulWidget {
  final String audioDirectory;
  final bool isVoiceHistory;
  const AudioSelectionScreen({
    Key? key,
    required this.audioDirectory,
    this.isVoiceHistory = false,
  }) : super(key: key);

  @override
  _AudioSelectionScreenState createState() => _AudioSelectionScreenState();
}

class _AudioSelectionScreenState extends State<AudioSelectionScreen> {
  late Future<Map<String, List<FileSystemEntity>>> _categorizedFiles;

  @override
  void initState() {
    super.initState();
    _categorizedFiles = _loadCategorizedAudioFiles();
  }

  Future<Map<String, List<FileSystemEntity>>>
      _loadCategorizedAudioFiles() async {
    List<FileSystemEntity> originalVoices = [];
    List<FileSystemEntity> clonedVoices = [];

    // Load from main directories (same as Home Screen logic)
    Directory directory = await getApplicationDocumentsDirectory();
    if (Platform.isAndroid) {
      // Check music folder first (same as VoiceCloningScreen)
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        directory = dirs.first;
      }
    }

    // Load original voices from the main directory
    if (await directory.exists()) {
      final mainFiles = await directory.list().toList();
      originalVoices.addAll(mainFiles.where((e) {
        final ext = e.path.split('.').last.toLowerCase();
        return ext == 'aac' || ext == 'wav';
      }));
    }

    // Also check application documents directory if different from above
    final documentsDir = await getApplicationDocumentsDirectory();
    if (directory.path != documentsDir.path) {
      if (await documentsDir.exists()) {
        final docFiles = await documentsDir.list().toList();
        originalVoices.addAll(docFiles.where((e) {
          final ext = e.path.split('.').last.toLowerCase();
          return ext == 'aac' || ext == 'wav';
        }));
      }
    }

    // Load from cloned voices directory (in documents folder)
    final clonedDir = Directory('${documentsDir.path}/cloned_voices');
    if (await clonedDir.exists()) {
      final clonedFiles = await clonedDir.list().toList();
      clonedVoices.addAll(clonedFiles.where((e) {
        final ext = e.path.split('.').last.toLowerCase();
        return ext == 'wav';
      }));
    }

    // Remove duplicates (in case same file exists in both directories)
    originalVoices = originalVoices.toSet().toList();

    // Sort both categories by modification date, newest first
    originalVoices.sort((a, b) {
      final aFile = File(a.path);
      final bFile = File(b.path);
      return bFile.lastModifiedSync().compareTo(aFile.lastModifiedSync());
    });

    clonedVoices.sort((a, b) {
      final aFile = File(a.path);
      final bFile = File(b.path);
      return bFile.lastModifiedSync().compareTo(aFile.lastModifiedSync());
    });

    return {
      'original': originalVoices,
      'cloned': clonedVoices,
    };
  }

  // Play the selected audio file using the default handler
  Future<void> _playFile(String path) async {
    await OpenFile.open(path);
  }

  // Delete the selected audio file and refresh the list
  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _categorizedFiles = _loadCategorizedAudioFiles();
    });
  }

  // Clear all voices function
  Future<void> _clearAllVoices() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Voices'),
          content: const Text(
              'Are you sure you want to delete all voice recordings and cloned voices? This action cannot be undone.'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF4242DC))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete All',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Delete from main directory
        final mainDir = Directory(widget.audioDirectory);
        if (await mainDir.exists()) {
          final mainFiles = await mainDir.list().toList();
          for (final entity in mainFiles) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (ext == 'aac' || ext == 'wav') {
                await entity.delete();
              }
            }
          }
        }

        // Delete from cloned voices directory
        final clonedDir = Directory('${widget.audioDirectory}/cloned_voices');
        if (await clonedDir.exists()) {
          final clonedFiles = await clonedDir.list().toList();
          for (final entity in clonedFiles) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (ext == 'wav') {
                await entity.delete();
              }
            }
          }
        }

        // Refresh the list
        setState(() {
          _categorizedFiles = _loadCategorizedAudioFiles();
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All voices deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting voices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isVoiceHistory ? 'Voice History' : 'Pick Your Voice'),
        backgroundColor: const Color(0xFF2E00AC),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _clearAllVoices,
              icon:
                  const Icon(Icons.delete_sweep, size: 18, color: Colors.white),
              label: const Text(
                'Clear All',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<Map<String, List<FileSystemEntity>>>(
          future: _categorizedFiles,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data ?? {};
            final originalVoices = data['original'] ?? [];
            final clonedVoices = data['cloned'] ?? [];

            if (originalVoices.isEmpty && clonedVoices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      widget.isVoiceHistory
                          ? 'No Voice History Found'
                          : 'No Voices Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isVoiceHistory
                          ? 'Record some voices or create cloned voices to see them here'
                          : 'Record some voices first to select for cloning',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show content based on context
                  if (widget.isVoiceHistory) ...[
                    // Voice History - Show both sections
                    // Original Voices Section
                    if (originalVoices.isNotEmpty) ...[
                      _buildSectionHeader('Voice Recordings',
                          originalVoices.length, const Color(0xFF2E00AC)),
                      const SizedBox(height: 16),
                      ...originalVoices
                          .map((file) => _buildVoiceCard(file as File, false)),
                      const SizedBox(height: 32),
                    ],

                    // Cloned Voices Section
                    if (clonedVoices.isNotEmpty) ...[
                      _buildSectionHeader('Cloned Voices', clonedVoices.length,
                          const Color(0xFF2E00AC)),
                      const SizedBox(height: 16),
                      ...clonedVoices
                          .map((file) => _buildVoiceCard(file as File, true)),
                    ],
                  ] else ...[
                    // Pick Your Voice - Show only original voices
                    if (originalVoices.isNotEmpty) ...[
                      _buildSectionHeader('Select Voice to Clone',
                          originalVoices.length, const Color(0xFF2E00AC)),
                      const SizedBox(height: 16),
                      ...originalVoices
                          .map((file) => _buildVoiceCard(file as File, false)),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            title.contains('Recording') ? Icons.mic : Icons.auto_awesome,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCard(File file, bool isCloned) {
    final name = file.path.split(Platform.pathSeparator).last;
    final color = const Color(0xFF2E00AC); // Same blue color for both types

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SynthesizeScreen(audioSamplePath: file.path),
          ),
        );
      },
      child: Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Voice type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCloned ? 'CLONED' : 'ORIGINAL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCloned ? 'AI Generated Voice' : 'Voice Recording',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _playFile(file.path),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _deleteFile(file.path),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
