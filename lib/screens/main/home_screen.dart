import 'package:flutter/material.dart';
import 'dart:io';
import '../../widgets/custom_bottom_navbar.dart';
import 'face_scan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'cloned_voices_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../microphone/recent_played_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const VoiceAvatarApp());
}

class VoiceAvatarApp extends StatelessWidget {
  const VoiceAvatarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Avatar App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F3CFA)),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String? imagePath;
  const HomeScreen({super.key, this.imagePath});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = 'User';
  String _userEmail = '';
  String? _userImagePath;
  late Future<List<File>> _recentVoicesFuture;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _recentVoicesFuture = _loadRecentVoices();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Debug: Print all stored values
    print('=== DEBUG: SharedPreferences values ===');
    print('user_name: ${prefs.getString('user_name')}');
    print('user_email: ${prefs.getString('user_email')}');
    print('user_image_path: ${prefs.getString('user_image_path')}');
    print('is_logged_in: ${prefs.getBool('is_logged_in')}');
    print('remember_me: ${prefs.getBool('remember_me')}');
    print('=====================================');

    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? 'No Email';
      _userImagePath = prefs.getString('user_image_path');
    });

    // If user data is missing, try to get from Firebase Auth
    if (_userName == 'User' || _userEmail == 'No Email') {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('=== Loading data from Firebase Auth ===');
        print('Firebase user name: ${user.displayName}');
        print('Firebase user email: ${user.email}');

        setState(() {
          _userName = user.displayName ?? 'User';
          _userEmail = user.email ?? 'No Email';
        });

        // Save to SharedPreferences for next time
        await prefs.setString('user_name', _userName);
        await prefs.setString('user_email', _userEmail);
        if (user.photoURL != null) {
          await prefs.setString('user_image_path', user.photoURL!);
          setState(() {
            _userImagePath = user.photoURL;
          });
        }
      }
    }
  }

  Future<List<File>> _loadRecentVoices() async {
    Directory directory = await getApplicationDocumentsDirectory();
    if (Platform.isAndroid) {
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        directory = dirs.first;
      }
    }
    final all = await directory.list().toList();
    return all
        .whereType<File>()
        .where((f) => f.path.endsWith('.aac') || f.path.endsWith('.wav'))
        .toList();
  }

  Future<void> _playRecording(String path) async {
    if (!_player.isOpen()) await _player.openPlayer();
    await _player.startPlayer(
      fromURI: path,
      codec: Platform.isAndroid ? Codec.aacMP4 : Codec.pcm16WAV,
      whenFinished: () async {
        await _player.closePlayer();
      },
    );
  }

  Future<void> _saveRecording(String path) async {
    Directory directory = await getApplicationDocumentsDirectory();
    if (Platform.isAndroid) {
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        directory = dirs.first;
      }
    }
    final fileName = path.split('/').last;
    final destPath = '${directory.path}/$fileName';
    await File(path).copy(destPath);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved to $destPath')));
    }
  }

  Future<void> _deleteRecording(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _recentVoicesFuture = _loadRecentVoices();
    });
  }

  Future<void> _renameRecording(String path) async {
    final file = File(path);
    final directory = file.parent;
    final oldName = file.uri.pathSegments.last;
    final dotIndex = oldName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? oldName.substring(0, dotIndex) : oldName;
    final extension = dotIndex != -1 ? oldName.substring(dotIndex) : '';
    final controller = TextEditingController(text: baseName);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Recording'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
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
    if (result != null && result.isNotEmpty) {
      final newPath = '${directory.path}/$result$extension';
      await file.rename(newPath);
      setState(() {
        _recentVoicesFuture = _loadRecentVoices();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F3CFA),
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.pushNamed(context, '/voice_cloning').then((_) {
            setState(() {
              _recentVoicesFuture = _loadRecentVoices();
            });
          });
        },
        child: const Icon(Icons.mic, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0,
        onItemSelected: (index) {
          if (index == 0) {
            // Already on Home
          } else if (index == 1) {
            Navigator.pushNamed(context, '/profile_settings');
          }
        },
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Stack(
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF2E00AC)),
                  accountName: Text(_userName),
                  accountEmail: Text(_userEmail),
                  currentAccountPicture: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          backgroundImage: (_userImagePath != null &&
                                  File(_userImagePath!).existsSync())
                              ? FileImage(File(_userImagePath!))
                              : null,
                          child: (_userImagePath == null ||
                                  !File(_userImagePath!).existsSync())
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Color(0xFF2E00AC),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home Page"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: const Text("Saved Voices"),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const RecentPlayedScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text('Cloned Voices'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const ClonedVoicesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text("Saved Videos"),
              onTap: () => Navigator.pushNamed(context, '/saved_avatars'),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Log Out",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('remember_me', false);
                await AuthService().signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E00AC),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Home Screen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildActionCards(context),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/chatbot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F3FA8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Tap to Talk with VocatwinBot!',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      FontAwesomeIcons.robot,
                      size: 24,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildRecentVoices(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Display dynamic greeting with user's last name (max 8 chars)
    String lastName = _userName.trim().split(' ').length > 1
        ? _userName.trim().split(' ').last
        : _userName.trim();
    if (lastName.length > 8) lastName = lastName.substring(0, 8);
    // Capitalize first letter
    if (lastName.isNotEmpty)
      lastName = lastName[0].toUpperCase() + lastName.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hi!",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4242DC),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'Welcome ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: '$lastName!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4242DC), // Special color for the name
                    ),
                  ),
                  const TextSpan(
                    text: '👋🏻',
                    style: TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
            _buildProfileAvatar(),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: (_userImagePath != null && File(_userImagePath!).existsSync())
          ? Image.file(
              File(_userImagePath!),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/images/profile_image.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Row(
      children: [
        // First tappable card
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/voice_cloning').then((_) {
                setState(() {
                  _recentVoicesFuture = _loadRecentVoices();
                });
              });
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white24,
            child: _buildActionCard(
              color: const Color(0xFF7B61FF),
              icon: Icons.mic,
              title: 'Record &\nsave Avatar',
              actionIcon: Icons.play_circle_fill,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Second tappable card
        Expanded(
          child: InkWell(
            onTap: () {
              debugPrint('Scan Your Face card tapped');
              Navigator.pushNamed(context, '/face_scan');
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white24,
            child: _buildActionCard(
              color: const Color(0xFFFFA726),
              icon: Icons.face_retouching_natural,
              title: 'Scan your\nFace',
              actionIcon: Icons.arrow_forward,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required Color color,
    required IconData icon,
    required String title,
    required IconData actionIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Icon(actionIcon, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  Widget _buildRecentVoices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT VOICES',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<File>>(
          future: _recentVoicesFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final files = snap.data ?? [];
            if (files.isEmpty) return const Text('No recordings yet');
            return Column(
              children: files.map((file) => _buildVoiceItem(file)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVoiceItem(File file) {
    final name = file.path.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.play_circle_fill,
                    color: Color(0xFF2F3CFA), size: 28),
                onPressed: () => _playRecording(file.path),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 24),
                onPressed: () => _renameRecording(file.path),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 26),
                onPressed: () => _deleteRecording(file.path),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
