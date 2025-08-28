import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'complete_profile_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  
  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _resendCooldown--);
        return _resendCooldown > 0;
      }
      return false;
    });
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);
    
    try {
      await SupabaseConfig.client.auth.signInWithOtp(
        email: widget.phoneNumber,
        emailRedirectTo: null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New OTP sent to your email!'),
            backgroundColor: Colors.green,
          ),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to resend OTP';
        if (e.toString().contains('rate_limit')) {
          errorMessage = 'Please wait before requesting another OTP';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final otp = _otpController.text.trim();
      
      try {
        // Use Supabase to verify email confirmation
        final response = await SupabaseConfig.client.auth.verifyOTP(
          email: widget.phoneNumber,
          token: otp,
          type: OtpType.email,
        );
        
        if (response.session != null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CompleteProfileScreen(email: widget.phoneNumber),
              ),
            );
          }
        } else {
          throw Exception('Invalid OTP');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid OTP: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                
                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.sms_outlined,
                      size: 40,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                const Text(
                  'Verify Your Number',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 10),
                
                Text(
                  'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 50),
                
                // OTP Input
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Enter OTP',
                    hintText: '000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the OTP';
                    }
                    if (value.length != 6) {
                      return 'OTP must be 6 digits';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                
                const SizedBox(height: 30),
                
                // Resend OTP
                TextButton(
                  onPressed: (_resendCooldown > 0 || _isResending) ? null : _resendOTP,
                  child: _isResending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Didn\'t receive the code? Resend',
                          style: TextStyle(
                            color: (_resendCooldown > 0 || _isResending)
                                ? Colors.grey
                                : Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
