import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  
  Future<void> _sendOTP(String email) async {
    try {
      // Use signInWithOtp instead of signUp to avoid rate limiting issues
      await SupabaseConfig.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your email! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(phoneNumber: email),
        ),
      );
    } catch (e) {
      print('OTP send error: $e');
      if (!mounted) return;
      
      String errorMessage = 'Failed to send OTP';
      if (e.toString().contains('rate_limit')) {
        errorMessage = 'Please wait before requesting another OTP';
      } else if (e.toString().contains('invalid_email')) {
        errorMessage = 'Please enter a valid email address';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40),
              children: [
            const Text(
              'Sign up for Line ko Status',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g. bipasha@example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final email = emailController.text.trim();

                  if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid email address')),
                    );
                    return;
                  }

                  setState(() => isLoading = true);
                  await _sendOTP(email);
                  setState(() => isLoading = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send OTP', style: TextStyle(color: Colors.white)),
              ),
            ),
            
            // Add responsive spacing instead of Spacer
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),

            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Already have an account? Log in",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1976D2),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            ],
            );
          },
        ),
      ),
    );
  }
}
