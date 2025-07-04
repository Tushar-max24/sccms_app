import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 📱 Screens
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/cleaning_staff_dashboard.dart';

/// 🔔 Background FCM Handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔕 Background FCM message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔧 Setup background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 🧠 Decide the starting screen
  Future<Widget> _getStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final role = prefs.getString('user_role');
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && rememberMe) {
      if (!user.emailVerified) {
        // If the user's email is not verified, redirect them to the login screen
        return const LoginScreen(role: 'user');
      }

      // 🔐 Initialize FCM for this user
      await _initFCM(user.uid);

      // 🎯 Route based on saved role
      switch (role) {
        case 'admin':
          return AdminDashboardScreen();
        case 'user':
          return const HomeScreen();
        case 'staff':
          return CleaningStaffDashboard(staffName: user.displayName ?? 'Staff');
        default:
          return const RoleSelectionScreen();  // Show role selection if no valid role is found
      }
    }

    // If user is not logged in or 'remember me' is false, show role selection screen
    return const RoleSelectionScreen();
  }

  /// 🔐 Setup FCM and store the token in Firestore
  Future<void> _initFCM(String userId) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions to show notifications
    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      if (token != null) {
        // Store the FCM token in Firestore for the current user
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
        });
        print("✅ FCM Token updated for $userId: $token");
      }
    }

    // Foreground FCM listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print("📨 Foreground FCM: ${message.notification?.title}");
        // Handle your notification here (e.g., show a dialog or banner)
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Campus Cleanliness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF388E3C),
          foregroundColor: Colors.white,
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _getStartScreen(),
        builder: (context, snapshot) {
          // Display loading spinner while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            // Display error if there's an issue
            return const Scaffold(
              body: Center(child: Text("Something went wrong. Please restart the app.")),
            );
          }

          // Return the appropriate screen based on the logic above
          return snapshot.data!;
        },
      ),
    );
  }
}
