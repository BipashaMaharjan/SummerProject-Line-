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
  bool _showAllUsers = false; // New debug filter
  String _searchQuery = '';

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
      var query = SupabaseConfig.client
          .from('profiles')
          .select('*, assigned_room:rooms!assigned_room_id(id, name)');
      
      if (!_showAllUsers) {
        query = query.or('role.eq.staff,email.ilike.%@work.com');
      }
      
      final response = await query.order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load staff members. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStaffStatus(String userId, bool currentStatus) async {
    // Optimistic update
    final index = _staffList.indexWhere((s) => s['id'] == userId);
    if (index != -1) {
      setState(() {
        _staffList[index]['is_active'] = !currentStatus;
      });
    }

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .update({'is_active': !currentStatus})
          .eq('id', userId)
          .select(); // Calling select() ensures we get the updated row back

      if (response.isEmpty) {
        throw Exception('No profiles were updated. You might not have permission.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Staff account ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
             duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling staff status: $e');
      // Revert optimistic update
      if (index != -1) {
        setState(() {
          _staffList[index]['is_active'] = currentStatus;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString().contains('permission') ? 'Permission Denied' : 'Error occurred'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> staff) async {
    List<Map<String, dynamic>> rooms = [];
    String? selectedRoomId = staff['assigned_room_id'];
    bool isUpdating = false;

    // Load rooms
    try {
      final response = await SupabaseConfig.client
          .from('rooms')
          .select('id, name')
          .order('name', ascending: true);
      rooms = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading rooms: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Room Assignment - ${staff['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current: ${_getRoomName(staff)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRoomId,
                decoration: const InputDecoration(
                  labelText: 'Select New Room',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room),
                ),
                items: rooms.map((room) {
                  return DropdownMenuItem<String>(
                    value: room['id'],
                    child: Text(room['name'] ?? 'Unknown Room'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedRoomId = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                if (selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a room')),
                  );
                  return;
                }
                
                setDialogState(() => isUpdating = true);

                try {
                  await SupabaseConfig.client
                      .from('profiles')
                      .update({
                        'assigned_room_id': selectedRoomId,
                        'role': 'staff', // Force role to staff when assigning a room
                      })
                      .eq('id', staff['id']);

                  if (mounted) {
                    // Close dialog first
                    Navigator.of(context, rootNavigator: true).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Room assignment updated successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    
                    // Then reload data
                    _loadStaff();
                  }
                } catch (e) {
                  if (mounted) {
                    setDialogState(() => isUpdating = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isUpdating 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoomName(Map<String, dynamic> staff) {
    // 1. Check for the aliased 'assigned_room' first (this is what my new query uses)
    final assignedRoom = staff['assigned_room'];
    if (assignedRoom != null) {
      if (assignedRoom is Map) return assignedRoom['name']?.toString() ?? 'Not Assigned';
      if (assignedRoom is List && assignedRoom.isNotEmpty) return assignedRoom[0]['name']?.toString() ?? 'Not Assigned';
    }

    // 2. Check for the default 'rooms' join (old behavior fallback)
    final rooms = staff['rooms'];
    if (rooms != null) {
      if (rooms is Map) return rooms['name']?.toString() ?? 'Not Assigned';
      if (rooms is List && rooms.isNotEmpty) return rooms[0]['name']?.toString() ?? 'Not Assigned';
    }
    
    // 3. Last Resort: If we have an ID but no join data, it's a join failure
    if (staff['assigned_room_id'] != null) {
      return 'Room ID: ${staff['assigned_room_id'].toString().substring(0, 5)}...';
    }
    
    return 'Not Assigned';
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
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStaffScreen()),
          );
          if (result == true) {
            _loadStaff();
          }
        },
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Staff Only'),
                  selected: !_showAllUsers,
                  onSelected: (selected) {
                    setState(() => _showAllUsers = false);
                    _loadStaff();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All Users'),
                  selected: _showAllUsers,
                  onSelected: (selected) {
                    setState(() => _showAllUsers = true);
                    _loadStaff();
                  },
                ),
                const Spacer(),
                Text(
                  '${_getFilteredStaff().length} found',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
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
                    : _getFilteredStaff().isEmpty
                        ? Center(
                            child: Text(_searchQuery.isEmpty 
                                ? 'No staff members found' 
                                : 'No matches for "$_searchQuery"'),
                          )
                        : ListView.builder(
                            itemCount: _getFilteredStaff().length,
                            itemBuilder: (context, index) {
                              final staff = _getFilteredStaff()[index];
                              final roomName = _getRoomName(staff);
                              final hasRoom = roomName != 'Not Assigned' && !roomName.startsWith('Room ID:');
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: staff['is_active'] == false 
                                        ? Colors.grey[300] 
                                        : Theme.of(context).primaryColor.withOpacity(0.1),
                                    child: Text(
                                      staff['full_name']?[0]?.toString().toUpperCase() ?? '?',
                                      style: TextStyle(
                                        color: staff['is_active'] == false ? Colors.grey : Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          staff['full_name'] ?? 'No Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: staff['is_active'] == false
                                                ? Colors.grey
                                                : null,
                                            decoration: staff['is_active'] == false 
                                                ? TextDecoration.lineThrough 
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (staff['role'] == 'admin')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'ADMIN',
                                            style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(staff['email'] ?? 'No Email'),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.meeting_room, size: 14, color: hasRoom ? Colors.blue : Colors.orange),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Room: $roomName',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: hasRoom ? Colors.blue : Colors.orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            staff['is_active'] == true ? Icons.check_circle : Icons.error_outline,
                                            size: 14,
                                            color: staff['is_active'] == true ? Colors.green : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
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
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_note, color: Colors.blue),
                                        onPressed: () => _showEditDialog(staff),
                                        tooltip: 'Edit Assignment',
                                      ),
                                      const VerticalDivider(width: 1),
                                      Switch(
                                        value: staff['is_active'] == true,
                                        activeColor: Colors.green,
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
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredStaff() {
    if (_searchQuery.isEmpty) return _staffList;
    return _staffList.where((staff) {
      final name = (staff['full_name'] ?? '').toString().toLowerCase();
      final email = (staff['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }
}