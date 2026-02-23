import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/social_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Still connecting to Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0B1220),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF22D3EE),
                ),
              ),
            );
          }

          // User is logged in and email is verified
          final user = snapshot.data;
          if (user != null && user.emailVerified) {
            return const HomeScreen();
          }

          // Not logged in (or email not verified)
          return const SocialLoginScreen();
        },
      ),
    );
  }
}
