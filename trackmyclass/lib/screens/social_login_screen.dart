import 'package:flutter/material.dart';

class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen> {
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
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 140,
              left: -40,
              child: Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
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
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "TrackMyClass",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
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
