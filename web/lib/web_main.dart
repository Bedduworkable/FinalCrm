import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../lib/firebase_options.dart';
import '../../lib/auth_service.dart';
import 'layouts/web_dashboard.dart';
import 'layouts/web_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const WebRealEstateCRM());
}

class WebRealEstateCRM extends StatelessWidget {
  const WebRealEstateCRM({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGPL CRM - Web',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10187B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const WebAuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebAuthWrapper extends StatelessWidget {
  const WebAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const WebDashboard();
        }
        return const WebAuthScreen();
      },
    );
  }
}