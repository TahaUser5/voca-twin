import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../main/avatar_screen.dart';

class SavedAvatarsScreen extends StatefulWidget {
  const SavedAvatarsScreen({Key? key}) : super(key: key);

  @override
  _SavedAvatarsScreenState createState() => _SavedAvatarsScreenState();
}

class _SavedAvatarsScreenState extends State<SavedAvatarsScreen> {
  late Future<List<File>> _avatarFilesFuture;
  Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _avatarFilesFuture = _loadAvatarFiles();
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<File>> _loadAvatarFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final all = Directory(dir.path).listSync();
    final files = all
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mp4'))
        .toList();

    // Sort by modification date, newest first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy • HH:mm').format(dateTime);
  }

  Future<void> _playVideo(String path) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarScreen(videoPath: path),
      ),
    );
  }

  Future<void> _deleteVideo(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text(
            'Are you sure you want to delete this video? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        _avatarFilesFuture = _loadAvatarFiles();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video deleted successfully')),
      );
    }
  }

  Future<void> _renameVideo(String oldPath) async {
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
        title: const Text('Rename Video'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != baseName) {
      final newPath = '${directory.path}/$newName$extension';
      try {
        await file.rename(newPath);
        setState(() {
          _avatarFilesFuture = _loadAvatarFiles();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video renamed to "$newName"')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming video: $e')),
        );
      }
    }
  }

  Future<void> _shareVideo(String path) async {
    try {
      await Share.shareXFiles([XFile(path)],
          text: 'Check out my avatar video!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing video: $e')),
      );
    }
  }

  Widget _buildVideoThumbnail(File file) {
    final path = file.path;

    if (!_videoControllers.containsKey(path)) {
      _videoControllers[path] = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }

    final controller = _videoControllers[path]!;

    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : const Center(
                child: Icon(Icons.video_library, color: Colors.grey),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E00AC),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Saved Videos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0,
        onItemSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/profile_settings');
          }
        },
      ),
      body: FutureBuilder<List<File>>(
        future: _avatarFilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading videos...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _avatarFilesFuture = _loadAvatarFiles();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved videos found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate an avatar to see it here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final name = file.path.split(Platform.pathSeparator).last;
              final fileSize = file.lengthSync();
              final lastModified = file.lastModifiedSync();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Video thumbnail
                      _buildVideoThumbnail(file),
                      const SizedBox(width: 16),

                      // Video info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B2BA4),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFileSize(fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(lastModified),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Play button
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  color: Color(0xFF2E00AC),
                                  size: 28,
                                ),
                                onPressed: () => _playVideo(file.path),
                                tooltip: 'Play Video',
                              ),

                              // More options
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'rename':
                                      _renameVideo(file.path);
                                      break;
                                    case 'share':
                                      _shareVideo(file.path);
                                      break;
                                    case 'delete':
                                      _deleteVideo(file.path);
                                      break;
                                  }
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
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share, size: 20),
                                        SizedBox(width: 8),
                                        Text('Share'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
