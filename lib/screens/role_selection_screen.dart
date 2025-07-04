import 'package:flutter/material.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Smart Campus Login"),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "👋 Welcome!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please select your role to continue",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Admin Login Button
                _buildRoleButton(
                  context,
                  icon: Icons.admin_panel_settings,
                  label: "Admin Login",
                  color: Colors.blueGrey,
                  role: "admin",
                ),

                const SizedBox(height: 20),

                // User Login Button
                _buildRoleButton(
                  context,
                  icon: Icons.person_outline,
                  label: "User Login",
                  color: Colors.teal,
                  role: "user",
                ),

                const SizedBox(height: 20),

                // Cleaning Staff Login Button
                _buildRoleButton(
                  context,
                  icon: Icons.cleaning_services,
                  label: "Cleaning Staff Login",
                  color: Colors.green,
                  role: "staff",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context,
      {required IconData icon,
        required String label,
        required Color color,
        required String role}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(role: role),
            ),
          );
        },
      ),
    );
  }
}
