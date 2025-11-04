import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import 'add_staff_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .like('email', '%@work.com')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load staff members. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStaffStatus(String userId, bool currentStatus) async {
    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'is_active': !currentStatus})
          .eq('id', userId);

      // Refresh the list
      await _loadStaff();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Staff account ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update staff status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaff,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStaffScreen()),
          ).then((_) => _loadStaff());
        },
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStaff,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _staffList.isEmpty
                  ? const Center(
                      child: Text('No staff members found'),
                    )
                  : ListView.builder(
                      itemCount: _staffList.length,
                      itemBuilder: (context, index) {
                        final staff = _staffList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                staff['full_name']?[0]?.toString().toUpperCase() ?? '?',
                              ),
                            ),
                            title: Text(
                              staff['full_name'] ?? 'No Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: staff['is_active'] == false
                                    ? Colors.grey
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staff['email'] ?? 'No Email'),
                                Text(
                                  'Role: ${staff['role'] ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Status: ${staff['is_active'] == true ? 'Active' : 'Inactive'}',
                                  style: TextStyle(
                                    color: staff['is_active'] == true
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: staff['is_active'] == true,
                                  onChanged: (value) {
                                    _toggleStaffStatus(
                                        staff['id'], staff['is_active'] == true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}