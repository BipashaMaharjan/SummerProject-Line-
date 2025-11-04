import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/supabase_config.dart';

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  List<Map<String, dynamic>> holidays = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    setState(() => isLoading = true);

    try {
      final response = await SupabaseConfig.client
          .from('holidays')
          .select()
          .order('date', ascending: true);

      setState(() {
        holidays = List<Map<String, dynamic>>.from(response as List);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading holidays: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _addHoliday() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _HolidayDialog(),
    );

    if (result != null) {
      try {
        await SupabaseConfig.client.from('holidays').insert({
          'date': result['date'],
          'name': result['name'],
          'description': result['description'],
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        _loadHolidays();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Holiday added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding holiday: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editHoliday(Map<String, dynamic> holiday) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _HolidayDialog(holiday: holiday),
    );

    if (result != null) {
      try {
        await SupabaseConfig.client
            .from('holidays')
            .update({
              'date': result['date'],
              'name': result['name'],
              'description': result['description'],
            })
            .eq('id', holiday['id']);

        _loadHolidays();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Holiday updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating holiday: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteHoliday(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: const Text('Are you sure you want to delete this holiday?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseConfig.client.from('holidays').delete().eq('id', id);

        _loadHolidays();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Holiday deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting holiday: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleHolidayStatus(Map<String, dynamic> holiday) async {
    try {
      await SupabaseConfig.client
          .from('holidays')
          .update({'is_active': !holiday['is_active']})
          .eq('id', holiday['id']);

      _loadHolidays();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
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
        title: const Text('Holidays Management'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHolidays,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHoliday,
        icon: const Icon(Icons.add),
        label: const Text('Add Holiday'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : holidays.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHolidays,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: holidays.length,
                    itemBuilder: (context, index) {
                      final holiday = holidays[index];
                      return _buildHolidayCard(holiday);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Holidays Added',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add holidays to manage system closures',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addHoliday,
            icon: const Icon(Icons.add),
            label: const Text('Add First Holiday'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(Map<String, dynamic> holiday) {
    final date = DateTime.parse(holiday['date']);
    final isActive = holiday['is_active'] ?? true;
    final isPast = date.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPast
                ? Colors.grey.shade200
                : isActive
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.event,
            color: isPast
                ? Colors.grey.shade600
                : isActive
                    ? Colors.blue.shade600
                    : Colors.orange.shade600,
          ),
        ),
        title: Text(
          holiday['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPast ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(date),
              style: TextStyle(
                color: isPast ? Colors.grey : Colors.grey.shade700,
              ),
            ),
            if (holiday['description'] != null &&
                holiday['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                holiday['description'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPast) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Past',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                Future.delayed(
                  Duration.zero,
                  () => _editHoliday(holiday),
                );
              },
            ),
            PopupMenuItem(
              child: ListTile(
                leading: Icon(isActive ? Icons.visibility_off : Icons.visibility),
                title: Text(isActive ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                Future.delayed(
                  Duration.zero,
                  () => _toggleHolidayStatus(holiday),
                );
              },
            ),
            PopupMenuItem(
              child: const ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                Future.delayed(
                  Duration.zero,
                  () => _deleteHoliday(holiday['id']),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HolidayDialog extends StatefulWidget {
  final Map<String, dynamic>? holiday;

  const _HolidayDialog({this.holiday});

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.holiday?['name'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.holiday?['description'] ?? '');
    _selectedDate = widget.holiday != null
        ? DateTime.parse(widget.holiday!['date'])
        : DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.holiday == null ? 'Add Holiday' : 'Edit Holiday'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Holiday Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter holiday name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'date': _selectedDate.toIso8601String().split('T')[0],
                'description': _descriptionController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.holiday == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
