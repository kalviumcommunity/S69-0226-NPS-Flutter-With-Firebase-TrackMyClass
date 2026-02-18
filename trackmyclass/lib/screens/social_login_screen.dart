import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'forgot_password/forgot_password_screen.dart';

class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _typingController;
  late Animation<int> _typingAnimation;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;
  final String _fullText = 'TrackMyClass';

  @override
  void initState() {
    super.initState();

    // Typing animation
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _typingAnimation = StepTween(begin: 0, end: _fullText.length).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );

    _typingController.forward();

    // Floating animation (up/down)
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _typingController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFF22D3EE);

    return Scaffold(
      backgroundColor: backgroundTop,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [backgroundTop, backgroundBottom],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Evenly Aligned Animated Educational Background Elements
            // Top Row
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 60 + _floatingAnimation.value,
                  left: 30,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 50,
                    color: const Color(0xFFFF9800).withOpacity(0.6),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 60 - _floatingAnimation.value,
                  right: 30,
                  child: Icon(
                    Icons.school_rounded,
                    size: 50,
                    color: const Color(0xFF9C27B0).withOpacity(0.6),
                  ),
                );
              },
            ),
            // Middle Row
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top:
                      MediaQuery.of(context).size.height * 0.25 +
                      _floatingAnimation.value,
                  left: 40,
                  child: Icon(
                    Icons.calculate_outlined,
                    size: 45,
                    color: const Color(0xFF4CAF50).withOpacity(0.6),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top:
                      MediaQuery.of(context).size.height * 0.25 -
                      _floatingAnimation.value,
                  right: 40,
                  child: Icon(
                    Icons.science_outlined,
                    size: 45,
                    color: const Color(0xFFE91E63).withOpacity(0.6),
                  ),
                );
              },
            ),
            // Center Row
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top:
                      MediaQuery.of(context).size.height * 0.45 -
                      _floatingAnimation.value,
                  left: 25,
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 48,
                    color: const Color(0xFFFFEB3B).withOpacity(0.6),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top:
                      MediaQuery.of(context).size.height * 0.45 +
                      _floatingAnimation.value,
                  right: 25,
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 48,
                    color: const Color(0xFFFFC107).withOpacity(0.7),
                  ),
                );
              },
            ),
            // Lower Row
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom:
                      MediaQuery.of(context).size.height * 0.25 +
                      _floatingAnimation.value,
                  left: 35,
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 46,
                    color: const Color(0xFF2196F3).withOpacity(0.6),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom:
                      MediaQuery.of(context).size.height * 0.25 -
                      _floatingAnimation.value,
                  right: 35,
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 46,
                    color: const Color(0xFF00BCD4).withOpacity(0.6),
                  ),
                );
              },
            ),
            // Bottom Row
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 80 - _floatingAnimation.value,
                  left: 50,
                  child: Text(
                    'π',
                    style: TextStyle(
                      fontSize: 36,
                      color: const Color(0xFFFF5722).withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: 80 + _floatingAnimation.value,
                  right: 50,
                  child: Text(
                    '∑',
                    style: TextStyle(
                      fontSize: 36,
                      color: const Color(0xFF3F51B5).withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            // Decorative circles with icons
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  top: -40 + _floatingAnimation.value * 0.5,
                  right: -40,
                  child: Container(
                    height: 180,
                    width: 180,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: -50 - _floatingAnimation.value * 0.5,
                  left: -50,
                  child: Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Typing Animation
                  AnimatedBuilder(
                    animation: _typingAnimation,
                    builder: (context, child) {
                      String displayText = _fullText.substring(
                        0,
                        _typingAnimation.value,
                      );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (_typingAnimation.value < _fullText.length)
                            Container(
                              width: 2,
                              height: 32,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Teacher-first attendance & progress",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _SlideToStart(
                      onSlideComplete: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          useSafeArea: true,
                          builder: (context) => const _LoginModal(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "Built for rural educators",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginModal extends StatefulWidget {
  const _LoginModal();

  @override
  State<_LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<_LoginModal> {
  bool _rememberMe = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That email is already registered. Try logging in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> _handleAuthAction() async {
    if (_isSubmitting) {
      return;
    }
    if (_isLogin) {
      await _handleLogin();
    } else {
      await _handleRegister();
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final subject = _subjectController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || subject.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));

      final user = credential.user;

      if (user == null) {
        _showMessage('Registration failed. Please try again.');
        return;
      }

      // ✅ Update display name
      await user.updateDisplayName(name);

      // ✅ Send verification email immediately
      await user.sendEmailVerification();

      // ✅ Sign out until verified
      await FirebaseAuth.instance.signOut();

      setState(() {
        _isLogin = true;
      });

      // ⭐ Show success popup BEFORE saving to Firestore
      _showMessage(
        'Verification email has been sent to $email.\n\n'
        'Please check your inbox and spam/junk folder to verify your account '
        'before logging in.',
      );

      // ✅ Save user data in background (fire-and-forget)
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'name': name,
            'subject': subject,
            'email': email,
            'emailVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .onError((error, stackTrace) {
            // Log error but don't show to user - email verification is what matters
            print('Firestore save error: $error');
          });
    } on TimeoutException {
      _showMessage('Request timed out. Check your connection and try again.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthError(error));
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));
      final user = credential.user;
      if (user == null) {
        _showMessage('Login failed. Please try again.');
        return;
      }
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        _showMessage('Email not verified. Verification email sent again.');
        return;
      }

      _showMessage('Login successful.');
    } on TimeoutException {
      _showMessage('Request timed out. Check your connection and try again.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthError(error));
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardBackground = Color(0xFFF8FAFC);
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + keyboardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Go ahead and set up\nyour account",
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sign in-up to enjoy the best managing experience",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      _buildSegment(
                        label: "Login",
                        isSelected: _isLogin,
                        onTap: () {
                          setState(() {
                            _isLogin = true;
                          });
                        },
                      ),
                      _buildSegment(
                        label: "Register",
                        isSelected: !_isLogin,
                        onTap: () {
                          setState(() {
                            _isLogin = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!_isLogin) ...[
                  const Text(
                    "Full Name",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        hintText: "Enter your full name",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Subject",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: "e.g., Mathematics, Science",
                        prefixIcon: const Icon(Icons.book_outlined),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  "Email Address",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "you@example.com",
                      prefixIcon: const Icon(Icons.mail_outline),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Password",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: "Enter your password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 14),
                  const Text(
                    "Confirm Password",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: "Re-enter your password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_isLogin)
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF0EA5A4),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Text(
                        "Remember me",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F917A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleAuthAction,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isLogin ? "Login" : "Register",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "Or login with",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: const Color(0xFFE2E8F0)),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                          icon: Image.network(
                            "https://img.icons8.com/color/48/google-logo.png",
                            height: 20,
                          ),
                          label: const Text(
                            "Google",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () {
                            // Google Sign-In Logic
                          },
                        ),
                      ),
                    ),
                    if (isIos) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: const Color(0xFFE2E8F0)),
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            icon: const Icon(Icons.apple, size: 18),
                            label: const Text(
                              "Apple",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () {
                              // Apple Sign-In Logic
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "By continuing, you agree to keep class data private.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0F172A) : Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideToStart extends StatefulWidget {
  final VoidCallback onSlideComplete;

  const _SlideToStart({required this.onSlideComplete});

  @override
  State<_SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<_SlideToStart> {
  double _dragPosition = 0;
  double _maxDrag = 0;

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF475569);
    const accent = Color(0xFF22D3EE);

    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = constraints.maxWidth - 70;

        return Container(
          height: 70,
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
          ),
          child: Stack(
            children: [
              // Background text/icons
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Start",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.double_arrow,
                      color: Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                  ],
                ),
              ),
              // Draggable button
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: _dragPosition,
                top: 5,
                bottom: 5,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx).clamp(
                        0.0,
                        _maxDrag,
                      );
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition >= _maxDrag * 0.8) {
                      // Slide completed
                      widget.onSlideComplete();
                      setState(() {
                        _dragPosition = 0;
                      });
                    } else {
                      // Snap back
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: bgColor,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
