import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Helper to show errors
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleAuth(bool isSignUp) async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        _showError("Please fill in all fields");
        return;
      }

      UserCredential credential;
      if (isSignUp) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // CRITICAL FOR STAGE 5: Create user document in Firestore
        // This allows other interns to search for you by email
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'uid': credential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // Fixes the "use_build_context_synchronously" error
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chats');
      
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Authentication failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleAuth(false),
                  child: const Text('Sign in'),
                ),
              ),
              TextButton(
                onPressed: () => _handleAuth(true),
                child: const Text('Don\'t have an account? Sign up'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}