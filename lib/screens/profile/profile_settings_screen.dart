import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_bottom_navbar.dart';
import 'package:path_provider/path_provider.dart';
import '../main/audio_selection_screen.dart';
import 'change_password_screen.dart';
import 'package:flutter/services.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen>
    with TickerProviderStateMixin {
  String _userName = '';
  String _userEmail = '';
  String? _userImagePath;
  final TextEditingController _ngrokUrlController = TextEditingController();

  late AnimationController _logoutAnimationController;
  late Animation<double> _logoutScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadNgrokUrl();

    // Initialize logout button animation
    _logoutAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _logoutScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _logoutAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _logoutAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _userEmail = prefs.getString('user_email') ?? '';
      _userImagePath = prefs.getString('user_image_path');
    });
  }

  Future<void> _loadNgrokUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ngrokUrlController.text = prefs.getString('ngrok_url') ?? 'URL not set';
    });
  }

  Future<void> _pasteAndSaveUrl() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final url = clipboardData?.text;
    if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ngrok_url', url);
      setState(() {
        _ngrokUrlController.text = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server URL saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid URL in clipboard.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _userImagePath = picked.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_image_path', _userImagePath!);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF4242DC)))),
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (r) => false);
            },
            child: const Text('Logout',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: const Color(0xFF4242DC)),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF4242DC))),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 16, color: Color(0xFF4242DC)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Deep blue header with centered white bold title
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2E00AC), // Deep blue background
            ),
            child: const Center(
              child: Text(
                'Profile Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text
                ),
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Info Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A5AE0),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundImage: _userImagePath != null
                                  ? FileImage(File(_userImagePath!))
                                  : const AssetImage(
                                          'assets/images/profile_image.png')
                                      as ImageProvider,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.camera_alt,
                                      size: 18, color: Color(0xFF6A5AE0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userEmail,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: InkWell(
                            onTap: () =>
                                Navigator.pushNamed(context, '/edit_profile'),
                            borderRadius: BorderRadius.circular(6),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF2E00AC),
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Content Management Section
                  const Text(
                    'Content Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E00AC),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingItem(
                      'Saved Videos',
                      'View and manage your saved avatar videos',
                      Icons.video_library,
                      () => Navigator.pushNamed(context, '/saved_avatars')),
                  _buildSettingItem(
                    'Voice History',
                    'Update or Delete your Voice History',
                    Icons.history,
                    () async {
                      final dir = await getApplicationDocumentsDirectory();
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AudioSelectionScreen(
                            audioDirectory: dir.path,
                            isVoiceHistory: true,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Account & Security Section
                  const Text(
                    'Account & Security',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E00AC),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingItem('Change Password',
                      'Update and Strengthen Account Security', Icons.lock, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  }),
                  _buildSettingItem(
                      'Notifications',
                      'Manage your notification preferences',
                      Icons.notifications,
                      () {}),

                  const SizedBox(height: 24),

                  // Technical Settings Section
                  const Text(
                    'Technical Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E00AC),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.dns,
                                color: Color(0xFF4242DC), size: 28),
                            title: Text('Server Address',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            subtitle: Text('Configure SadTalker server URL',
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF4242DC))),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _ngrokUrlController.text,
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4242DC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.paste, size: 20),
                              label: const Text('Paste & Save URL',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              onPressed: _pasteAndSaveUrl,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Support Section
                  const Text(
                    'Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E00AC),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingItem(
                      'Help Center',
                      'Find answers or connect with support',
                      Icons.help_outline,
                      () {}),

                  const SizedBox(height: 32),

                  // Logout Button - Smaller and Animated
                  Center(
                    child: GestureDetector(
                      onTapDown: (_) => _logoutAnimationController.forward(),
                      onTapUp: (_) => _logoutAnimationController.reverse(),
                      onTapCancel: () => _logoutAnimationController.reverse(),
                      onTap: _showLogoutDialog,
                      child: AnimatedBuilder(
                        animation: _logoutScaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoutScaleAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE53935),
                                    Color(0xFFD32F2F)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom navigation bar
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1,
        onItemSelected: (index) {
          if (index == 0) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
          } else if (index == 1) {
            // Already on Settings
          }
        },
      ),
    );
  }
}
