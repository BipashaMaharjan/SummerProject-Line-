import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/staff_service.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final StaffService _staffService = StaffService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  List<Map<String, dynamic>> _staffList = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAddingStaff = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final staff = await _staffService.getStaffList();
      setState(() {
        _staffList = staff;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load staff: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAddingStaff = true;
      _errorMessage = null;
    });

    try {
      await _staffService.addStaff(
        email: _emailController.text.trim(),
        fullName: _nameController.text.trim(),
        password: _passwordController.text,
      );
      
      // Clear form
      _emailController.clear();
      _nameController.clear();
      _passwordController.clear();
      
      // Reload staff list
      await _loadStaff();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff added successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add staff: $e';
      });
    } finally {
      setState(() {
        _isAddingStaff = false;
      });
    }
  }

  Future<void> _deleteStaff(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete $email? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _staffService.deleteStaff(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff deleted successfully')),
        );
      }
      await _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete staff: $e')),
        );
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      await _staffService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaff,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Staff Form
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add New Staff',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) => (value?.length ?? 0) < 6
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isAddingStaff ? null : _addStaff,
                      child: _isAddingStaff
                          ? const CircularProgressIndicator()
                          : const Text('Add Staff'),
                    ),
                    if (_errorMessage != null) ...{
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    },
                  ],
                ),
              ),
            ),
          ),
          // Staff List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staffList.isEmpty
                    ? const Center(child: Text('No staff members found'))
                    : ListView.builder(
                        itemCount: _staffList.length,
                        itemBuilder: (context, index) {
                          final staff = _staffList[index];
                          return ListTile(
                            title: Text(staff['full_name'] ?? 'No Name'),
                            subtitle: Text(staff['email'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  tooltip: 'Reset Password',
                                  onPressed: () => _resetPassword(staff['email']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  tooltip: 'Delete Staff',
                                  onPressed: () => _deleteStaff(
                                    staff['id'],
                                    staff['email'],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              // TODO: Implement edit staff
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}