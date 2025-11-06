import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';

class AuthDebugScreen extends StatelessWidget {
  const AuthDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final session = SupabaseConfig.client.auth.currentSession;
    final user = SupabaseConfig.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Debug'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Session Status',
              session != null ? '✅ Active' : '❌ None',
              session != null ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            
            _buildSection(
              'User Status',
              user != null ? '✅ Authenticated' : '❌ Not Authenticated',
              user != null ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            
            if (user != null) ...[
              _buildInfoCard('User ID', user.id),
              _buildInfoCard('Email', user.email ?? 'N/A'),
              _buildInfoCard('Created At', user.createdAt.toString()),
              _buildInfoCard('Last Sign In', user.lastSignInAt?.toString() ?? 'N/A'),
              const SizedBox(height: 16),
            ],
            
            _buildSection(
              'Profile Status',
              authProvider.profile != null ? '✅ Loaded' : '❌ Not Loaded',
              authProvider.profile != null ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            
            if (authProvider.profile != null) ...[
              _buildInfoCard('Full Name', authProvider.profile!.fullName ?? 'N/A'),
              _buildInfoCard('Role', authProvider.profile!.role.toString()),
              _buildInfoCard('Active', authProvider.profile!.isActive.toString()),
              const SizedBox(height: 16),
            ],
            
            if (authProvider.isProfileLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading profile...'),
                  ],
                ),
              ),
            
            if (authProvider.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authProvider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await authProvider.loadUser();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile reloaded')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reload Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (user != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await authProvider.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
