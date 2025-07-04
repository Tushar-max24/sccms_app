import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  String selectedRole = '';
  bool isLoading = false;
  bool agreeToTerms = false;
  String passwordStrength = '';

  Future<void> signUpUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a role")),
      );
      return;
    }

    if (!agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must accept the terms to continue")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': selectedRole,
        'uid': userCredential.user!.uid,
      });

      if (!mounted) return;
      Navigator.pop(context); // go back to login
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup failed")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void checkPasswordStrength(String password) {
    if (password.length < 6) {
      passwordStrength = 'Weak';
    } else if (password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[A-Z]'))) {
      passwordStrength = 'Strong';
    } else {
      passwordStrength = 'Medium';
    }
    setState(() {});
  }

  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Up"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: screenWidth > 500 ? 400 : double.infinity),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Full Name"),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter your name" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Enter email";
                      if (!isValidEmail(value)) return "Enter a valid email";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixText: passwordStrength,
                      suffixStyle: TextStyle(
                        color: passwordStrength == 'Strong'
                            ? Colors.green
                            : passwordStrength == 'Medium'
                            ? Colors.orange
                            : Colors.red,
                      ),
                    ),
                    onChanged: checkPasswordStrength,
                    validator: (value) =>
                    value != null && value.length < 6
                        ? "Password must be at least 6 characters"
                        : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedRole.isNotEmpty ? selectedRole : null,
                    decoration: const InputDecoration(labelText: "Select Role"),
                    items: ['user', 'admin', 'staff']
                        .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.toUpperCase()),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedRole = value ?? '');
                    },
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Select a role' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: agreeToTerms,
                        onChanged: (value) =>
                            setState(() => agreeToTerms = value ?? false),
                      ),
                      const Expanded(
                        child: Text("I agree to the Terms & Conditions."),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                    onPressed: signUpUser,
                    icon: const Icon(Icons.person_add),
                    label: const Text("Sign Up"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("← Back to Login"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
