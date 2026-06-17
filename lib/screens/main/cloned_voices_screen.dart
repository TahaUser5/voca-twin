import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class ClonedVoicesScreen extends StatefulWidget {
  const ClonedVoicesScreen({Key? key}) : super(key: key);

  @override
  _ClonedVoicesScreenState createState() => _ClonedVoicesScreenState();
}

class _ClonedVoicesScreenState extends State<ClonedVoicesScreen> {
  late Future<List<File>> _clonedVoicesFuture;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlaying = false;
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _clonedVoicesFuture = _loadClonedVoices();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<List<File>> _loadClonedVoices() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final clonedVoicesDir = Directory('${appDocDir.path}/cloned_voices');

    if (!await clonedVoicesDir.exists()) {
      return []; // Return empty list if directory doesn't exist
    }

    final all = await clonedVoicesDir.list().toList();
    final files =
        all.whereType<File>().where((f) => f.path.endsWith('.wav')).toList();
    // Sort by modification date, newest first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<void> _playRecording(String path) async {
    if (_player.isPlaying) {
      await _player.stopPlayer();
      if (_currentlyPlaying == path) {
        setState(() {
          _isPlaying = false;
          _currentlyPlaying = null;
        });
        return;
      }
    }

    await _player.startPlayer(
      fromURI: path,
      whenFinished: () {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentlyPlaying = null;
          });
        }
      },
    );
    setState(() {
      _isPlaying = true;
      _currentlyPlaying = path;
    });
  }

  Future<void> _deleteRecording(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _clonedVoicesFuture = _loadClonedVoices();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice deleted successfully')),
    );
  }

  Future<void> _renameRecording(String oldPath) async {
    final file = File(oldPath);
    final directory = file.parent;
    final oldName = file.uri.pathSegments.last;
    final dotIndex = oldName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? oldName.substring(0, dotIndex) : oldName;
    final extension = dotIndex != -1 ? oldName.substring(dotIndex) : '';
    final controller = TextEditingController(text: baseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Voice'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Enter new name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Rename')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final newPath = '${directory.path}/$newName$extension';
      if (await File(newPath).exists()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A file with this name already exists.')));
        return;
      }
      await file.rename(newPath);
      setState(() {
        _clonedVoicesFuture = _loadClonedVoices();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloned Voices'),
        backgroundColor: const Color(0xFF2E00AC),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: FutureBuilder<List<File>>(
        future: _clonedVoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No cloned voices found.'));
          }

          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final fileName = file.uri.pathSegments.last;
              final modDate = file.lastModifiedSync();
              final formattedDate =
                  DateFormat('MMM d, yyyy hh:mm a').format(modDate);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    Icons.multitrack_audio_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(formattedDate),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying && _currentlyPlaying == file.path
                              ? Icons.stop
                              : Icons.play_arrow,
                          color: Colors.green,
                        ),
                        onPressed: () => _playRecording(file.path),
                      ),
                      _buildMoreMenu(file),
                    ],
                  ),
                  onTap: () => _playRecording(file.path),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMoreMenu(File file) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'rename') {
          _renameRecording(file.path);
        } else if (value == 'delete') {
          _deleteRecording(file.path);
        } else if (value == 'share') {
          Share.shareXFiles([XFile(file.path)],
              text: 'Check out this cloned voice!');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'share', child: Text('Share')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
