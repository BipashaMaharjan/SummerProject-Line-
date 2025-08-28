import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
      ),
      body: const Center(
        child: Text('Staff management UI coming soon'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff'),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  if (!v.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              final ok = await _sendInviteAndRecord(name: name, email: email);
              if (!context.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Invite sent to $email'
                      : 'Failed to send invite'),
                ),
              );
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  Future<bool> _sendInviteAndRecord({required String name, required String email}) async {
    try {
      await SupabaseConfig.client.auth.signInWithOtp(email: email);
      // Record in staff_invites for automatic role assignment on first login
      await SupabaseConfig.client.from('staff_invites').upsert({
        'email': email,
        'name': name,
      });
      return true;
    } catch (e) {
      debugPrint('Invite error: $e');
      return false;
    }
  }
}