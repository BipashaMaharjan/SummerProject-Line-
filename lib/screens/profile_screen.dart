import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool isLoading = true;
  UserProfile? userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => isLoading = true);
    
    try {
      // Check if user is logged in first
      if (!_authService.isLoggedIn()) {
        print('User not logged in, redirecting to login');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // First try to get user from auth metadata
      final user = _authService.getCurrentUser();
      
      if (user != null) {
        print('Auth user data: ${user.fullName}');
        
        setState(() {
          userProfile = user;
          isLoading = false;
        });
        
        // Always try to fetch from database as well to get complete data
        await _loadUserFromDatabase();
      } else {
        print('No authenticated user found, redirecting to login');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _loadUserFromDatabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      print('Fetching user data from database for user: ${currentUser.id}');
      
      final user = await _authService.getUserFromDatabase(currentUser.id);
      if (user != null) {
        print('Database user data: ${user.fullName}');
        
        setState(() {
          // Prefer database data as it's more complete
          userProfile = user;
        });
      } else {
        print('No user data found in database');
      }
    } catch (e) {
      print('Error loading user from database: $e');
      // Keep the auth metadata values if database fetch fails
    }
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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

  void _showEditProfileDialog() {
    final _formKey = GlobalKey<FormState>();
    final _fullNameController = TextEditingController(text: userProfile?.fullName ?? '');
    final _phoneController = TextEditingController(text: userProfile?.phone ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  // Show loading
                  Navigator.of(context).pop();
                  setState(() => isLoading = true);
                  
                  try {
                    final updatedProfile = UserProfile(
                      id: userProfile?.id ?? _authService.getCurrentUser()?.id ?? '',
                      fullName: _fullNameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      role: userProfile?.role ?? UserRole.customer,
                      isActive: true,
                      createdAt: userProfile?.createdAt ?? DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    
                    final success = await _authService.updateUserProfile(updatedProfile);
                    
                    if (success) {
                      // Reload profile data from database
                      await _loadUserProfile();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully! '),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update profile. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => isLoading = false);
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: Container(
        color: const Color(0xFFF0F4FF),
        padding: const EdgeInsets.all(20),
        child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard(
                    title: 'Name',
                    value: userProfile?.fullName ?? 'Not provided',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Phone',
                    value: userProfile?.phone ?? 'Not provided',
                    icon: Icons.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'User Role',
                    value: userProfile?.role.name.toUpperCase() ?? 'CUSTOMER',
                    icon: Icons.people,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showEditProfileDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _authService.signOut();
                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
      ),
    ));
  }
}
