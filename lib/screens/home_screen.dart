import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import 'login_screen.dart';
import 'qr_code_scanner.dart';
import 'report_issue_screen.dart';
import 'view_reports_screen.dart';
import 'map_screen.dart';
import 'admin_dashboard_screen.dart';
import 'report_history_page.dart';
import 'waste_detector.dart'; // ✅ Import Waste Detector

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
    _checkAdminStatus();
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotificationDialog(
          message.notification!.title ?? 'New Message',
          message.notification!.body ?? '',
        );
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print("🔄 FCM Token refreshed: $newToken");
    });
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    setState(() {
      _isAdmin = role == 'admin';
    });
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    String? role = prefs.getString('user_role');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: role ?? 'user'),
      ),
    );
  }

  void _showNotificationDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Smart Clean Campus"),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Image.asset(
              'assets/banner_clean.png',
              fit: BoxFit.fitWidth,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Text(
                  "Welcome, ${user?.email ?? 'User'}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Your smart campus cleanliness companion",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.9,
                children: [
                  _buildCard("Scan QR Code", "assets/lottie/qr_scan.json", Colors.blue, const QRCodeScanner()),
                  _buildCard("Report Issue", "assets/lottie/report_issue.json", Colors.teal, const ReportIssueScreen()),
                  _buildCard("View My Reports", "assets/lottie/view_reports.json", Colors.orange, ViewReportsScreen()),
                  _buildCard("Basic Map", "assets/lottie/map.json", Colors.indigo, MapScreen()),
                  _buildCard("Past Reports", "assets/lottie/history.json", Colors.purple, ReportHistoryPage(isAdmin: _isAdmin)),
                  _buildCard("Waste Detector", "assets/lottie/dust.json", Colors.green, WasteDetector()),
                  if (_isAdmin)
                    _buildCard("Admin Dashboard", "assets/lottie/admin.json", Colors.redAccent, AdminDashboardScreen()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String lottiePath, Color color, Widget destinationScreen) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destinationScreen),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Lottie.asset(lottiePath)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}