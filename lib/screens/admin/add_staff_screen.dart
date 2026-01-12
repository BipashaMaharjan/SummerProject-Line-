import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  _AddStaffScreenState createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingRooms = true;
  List<Map<String, dynamic>> _rooms = [];
  String? _selectedRoomId;
  String? _roomError;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final response = await SupabaseConfig.client
          .from('rooms')
          .select('id, name')
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(response);
          _isLoadingRooms = false;
          if (_rooms.isNotEmpty) {
            _selectedRoomId = _rooms[0]['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading rooms: $e');
      if (mounted) {
        setState(() {
          _roomError = 'Failed to load rooms: $e';
          _isLoadingRooms = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createStaffAccount() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a room for the staff member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('🔄 Creating staff account...');
      debugPrint('📧 Email: ${_emailController.text.trim()}');
      
      // Create auth user with minimal data
      final authResponse = await SupabaseConfig.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'role': 'staff',
        },
      );

      debugPrint('📦 Auth response: ${authResponse.user?.id}');

      if (authResponse.user == null) {
        throw Exception('Failed to create auth user - no user returned');
      }

      final userId = authResponse.user!.id;
      debugPrint('✅ Auth user created: $userId');
      
      // Wait for trigger
      await Future.delayed(const Duration(seconds: 1));
      
      // Check if profile exists
      try {
        final profileCheck = await SupabaseConfig.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        
        if (profileCheck != null) {
          debugPrint('✅ Profile exists: ${profileCheck['full_name']}');
          // Update with room assignment if not already set
          if (profileCheck['assigned_room_id'] == null) {
            await SupabaseConfig.client
                .from('profiles')
                .update({'assigned_room_id': _selectedRoomId})
                .eq('id', userId);
            debugPrint('✅ Room assigned: $_selectedRoomId');
          }
        } else {
          debugPrint('⚠️ Profile not found, creating...');
          // Create profile manually with room assignment
          await SupabaseConfig.client.from('profiles').insert({
            'id': userId,
            'email': _emailController.text.trim(),
            'full_name': _nameController.text.trim(),
            'role': 'staff',
            'is_active': true,
            'assigned_room_id': _selectedRoomId,
          });
          debugPrint('✅ Profile created with room: $_selectedRoomId');
        }
      } catch (e) {
        debugPrint('❌ Profile error: $e');
        throw Exception('Failed to create profile: $e');
      }

      // Confirm email immediately for staff accounts
      try {
        await SupabaseConfig.client.rpc('confirm_user_email', params: {
          'user_id': userId,
        });
        debugPrint('✅ Email confirmed automatically');
      } catch (e) {
        debugPrint('⚠️ Email confirmation failed: $e');
        debugPrint('   Staff can still login, but may need to verify email');
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Staff account created successfully!\nEmail: ${_emailController.text.trim()}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      Navigator.pop(context);
      
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auth Error: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('❌ General error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Staff Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@work.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.endsWith('@work.com')) {
                    return 'Staff email must end with @work.com';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Room Selection Dropdown
              if (_isLoadingRooms)
                const Center(child: CircularProgressIndicator())
              else if (_roomError != null)
                Text(
                  _roomError!,
                  style: const TextStyle(color: Colors.red),
                )
              else if (_rooms.isEmpty)
                const Text(
                  'No rooms available. Please create rooms first.',
                  style: TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Assign Room',
                    hintText: 'Select a room for this staff member',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  items: _rooms.map((room) {
                    return DropdownMenuItem<String>(
                      value: room['id'],
                      child: Text(room['name'] ?? 'Unknown Room'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedRoomId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a room';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createStaffAccount,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Staff Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
