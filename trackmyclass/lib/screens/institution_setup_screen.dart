import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class InstitutionSetupScreen extends StatefulWidget {
  const InstitutionSetupScreen({super.key});

  @override
  State<InstitutionSetupScreen> createState() => _InstitutionSetupScreenState();
}

class _InstitutionSetupScreenState extends State<InstitutionSetupScreen> {
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _institutionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final institutionName = _institutionController.text.trim();
    final subject = _subjectController.text.trim();

    if (institutionName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your institution name')),
      );
      return;
    }
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the subject you teach')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'institutionName': institutionName,
          'subject': subject,
        }, SetOptions(merge: true));

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving details: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0B1220);
    const backgroundBottom = Color(0xFF111A2E);
    const accent = Color(0xFF22D3EE);
    const fieldBg = Color(0xFF1A2640);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: accent,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "One more step!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Tell us about your institution and what you teach.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),

                // Institution Name Field
                const Text(
                  "Institution Name",
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: TextField(
                    controller: _institutionController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: "e.g. Greenwood High, ABC Academy",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                      ),
                      prefixIcon: Icon(
                        Icons.apartment_rounded,
                        color: accent.withOpacity(0.8),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Subject Field
                const Text(
                  "Subject You Teach",
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: TextField(
                    controller: _subjectController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: "e.g. Mathematics, Science, History",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                      ),
                      prefixIcon: Icon(
                        Icons.book_outlined,
                        color: accent.withOpacity(0.8),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF0B1220),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(
                            color: Color(0xFF0B1220),
                          )
                        : const Text(
                            "Complete Setup",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "This helps us organize students and data specifically for your workspace.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
