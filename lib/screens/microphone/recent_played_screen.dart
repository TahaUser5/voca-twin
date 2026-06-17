import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_bottom_navbar.dart';

class RecentPlayedScreen extends StatefulWidget {
  const RecentPlayedScreen({super.key});

  @override
  _RecentPlayedScreenState createState() => _RecentPlayedScreenState();
}

class _RecentPlayedScreenState extends State<RecentPlayedScreen> {
  late Future<List<FileSystemEntity>> _filesFuture;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadSavedVoices();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<List<FileSystemEntity>> _loadSavedVoices() async {
    Directory directory;
    if (Platform.isAndroid) {
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        directory = dirs.first;
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (!await directory.exists()) {
      return [];
    }

    return directory
        .list()
        .where(
            (item) => item.path.endsWith('.wav') || item.path.endsWith('.aac'))
        .toList();
  }

  Future<void> _togglePlay(String path) async {
    if (_player.isPlaying && _currentlyPlaying == path) {
      await _player.stopPlayer();
      setState(() => _currentlyPlaying = null);
    } else {
      await _player.startPlayer(
        fromURI: path,
        whenFinished: () {
          setState(() => _currentlyPlaying = null);
        },
      );
      setState(() => _currentlyPlaying = path);
    }
  }

  Future<void> _renameFile(FileSystemEntity file) async {
    final oldPath = file.path;
    String? newName =
        await _showRenameDialog(file.path.split('/').last.split('.').first);
    if (newName != null && newName.isNotEmpty) {
      final newPath = '${file.parent.path}/$newName.${oldPath.split('.').last}';
      await File(oldPath).rename(newPath);
      setState(() {
        _filesFuture = _loadSavedVoices(); // Refresh the list
      });
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    await file.delete();
    setState(() {
      _filesFuture = _loadSavedVoices(); // Refresh the list
    });
  }

  Future<String?> _showRenameDialog(String initialName) {
    final controller = TextEditingController(text: initialName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Voice'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter new name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Rename')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Saved Voices",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B2BA4), // Deep blue
        iconTheme: const IconThemeData(color: Colors.white), // For back arrow
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0, // Default to home
        onItemSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/profile_settings');
          }
        },
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No saved voices found."));
          }

          final files = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final path = file.path;
              final name = path.split('/').last;
              final isPlaying = _currentlyPlaying == path;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            const Color(0xFF1B2BA4).withOpacity(0.1),
                        child: const Icon(
                          Icons.graphic_eq, // A better icon for audio
                          color: Color(0xFF1B2BA4),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<FileStat>(
                              future: file.stat(),
                              builder: (context, statSnapshot) {
                                if (statSnapshot.hasData) {
                                  final formattedDate =
                                      DateFormat('MMM d, yyyy HH:mm')
                                          .format(statSnapshot.data!.modified);
                                  return Text(
                                    'Saved: $formattedDate',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: const Color(0xFF1B2BA4), // Deep blue
                          size: 32,
                        ),
                        onPressed: () => _togglePlay(path),
                      ),
                      PopupMenuButton<String>(
                        icon:
                            Icon(Icons.more_vert, color: Colors.grey.shade700),
                        onSelected: (value) {
                          if (value == 'rename') _renameFile(file);
                          if (value == 'delete') _deleteFile(file);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Rename'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
