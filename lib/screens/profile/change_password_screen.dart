import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _showSuccessAnimation = false;
  String _userEmail = '';

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _buttonColorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _buttonColorAnimation = ColorTween(
      begin: const Color(0xFF4242DC),
      end: Colors.green,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));

    _checkPasswordChangeStatus();
    _loadUserEmail();
    _checkForPasswordUpdateConfirmation();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = prefs.getString('user_email') ?? user?.email ?? '';
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordChangeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final passwordChanged = prefs.getBool('password_change_success') ?? false;

    if (passwordChanged) {
      // Show success animation when returning to this screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessPopup();
        // Clear the flag
        prefs.setBool('password_change_success', false);
      });
    }
  }

  void _showSuccessPopup() {
    setState(() {
      _showSuccessAnimation = true;
    });
    _animationController.forward();
    _pulseController.repeat(reverse: true);

    // Auto hide after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showSuccessAnimation = false;
            });
            _pulseController.stop();
          }
        });
      }
    });
  }

  Future<void> _checkForPasswordUpdateConfirmation() async {
    final prefs = await SharedPreferences.getInstance();
    final hasConfirmedUpdate =
        prefs.getBool('password_confirmed_from_email') ?? false;

    if (hasConfirmedUpdate) {
      // Clear the flag first
      await prefs.setBool('password_confirmed_from_email', false);

      // Show success animation when user returns from email
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPasswordUpdatedAnimation();
      });
    }
  }

  void _showPasswordUpdatedAnimation() {
    setState(() {
      _showSuccessAnimation = true;
    });
    _animationController.forward();
    _pulseController.repeat(reverse: true);

    // Auto hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showSuccessAnimation = false;
            });
            _pulseController.stop();
          }
        });
      }
    });
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Store the new password temporarily in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'pending_new_password', _newPasswordController.text);
      await prefs.setString('pending_user_email', user.email!);
      await prefs.setBool('password_change_requested', true);

      // Send custom password reset email with confirmation
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);

      // Save success flag
      await prefs.setBool('password_change_success', true);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.email, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                    'Confirmation email sent! Check Gmail and confirm to update your password.'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 6),
        ),
      );

      // Clear form
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Show success animation after delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showSuccessPopup();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required IconData prefixIcon,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E00AC),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4242DC).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4242DC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(prefixIcon, color: const Color(0xFF4242DC), size: 20),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: const Color(0xFF4242DC),
                ),
                onPressed: onToggleVisibility,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF4242DC), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E00AC),
                  Color(0xFF4242DC),
                  Color(0xFF6A5AE0),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Custom App Bar with Deep Blue Background
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E00AC), // Deep blue background
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Change Password',
                                style: TextStyle(
                                  color: Colors.white, // White text
                                  fontSize: 24, // Larger font
                                  fontWeight: FontWeight.bold, // Bold text
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),

                              // Header Section
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF4242DC).withOpacity(0.1),
                                      const Color(0xFF6A5AE0).withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF4242DC)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4242DC)
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.security_rounded,
                                        color: Color(0xFF4242DC),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Secure Your Account',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E00AC),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Update your password to keep your account safe and secure.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Section 1: Gmail Verification Section
                              const Text(
                                'Gmail Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E00AC),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.indigo.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Image.asset(
                                            'assets/images/gmail_logo.png',
                                            width: 24,
                                            height: 24,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(
                                              Icons.email,
                                              color: Colors.blue.shade600,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Verification Email Address',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Password reset confirmation will be sent to:',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.verified_user,
                                            color: Colors.blue.shade600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _userEmail.isNotEmpty
                                                  ? _userEmail
                                                  : 'Loading...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Verified',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Section 2: New Password
                              const Text(
                                'New Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E00AC),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPasswordField(
                                label: 'Enter New Password',
                                controller: _newPasswordController,
                                obscureText: _obscureNewPassword,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a new password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                                prefixIcon: Icons.lock_rounded,
                                hintText: 'Enter your new password',
                              ),

                              const SizedBox(height: 32),

                              // Section 3: Repeat Password
                              const Text(
                                'Repeat Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E00AC),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPasswordField(
                                label: 'Confirm Your Password',
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                prefixIcon: Icons.lock_outline_rounded,
                                hintText: 'Repeat your new password',
                              ),

                              const SizedBox(height: 32),

                              // Submit Button with Animation
                              AnimatedBuilder(
                                animation: _buttonController,
                                builder: (context, child) {
                                  return Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          _buttonColorAnimation.value ??
                                              const Color(0xFF4242DC),
                                          _buttonColorAnimation.value != null
                                              ? (_buttonColorAnimation.value ==
                                                      Colors.green
                                                  ? Colors.green.shade600
                                                  : const Color(0xFF6A5AE0))
                                              : const Color(0xFF6A5AE0),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_buttonColorAnimation.value ??
                                                  const Color(0xFF4242DC))
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              _buttonController.forward();
                                              _changePassword();
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                    _buttonColorAnimation
                                                                .value ==
                                                            Colors.green
                                                        ? Icons.check_circle
                                                        : Icons
                                                            .security_update_good,
                                                    color: Colors.white),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _buttonColorAnimation.value ==
                                                          Colors.green
                                                      ? 'Email Sent!'
                                                      : 'Request Password Change',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 24),

                              // Info Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.email_outlined,
                                          color: Colors.blue.shade600),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Password Change Confirmation',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'A confirmation email will be sent to verify your password change request.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Success Animation Overlay
          if (_showSuccessAnimation)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.green, Color(0xFF4CAF50)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 16,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Password Changed\nSuccessfully!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E00AC),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Your password has been updated successfully!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
