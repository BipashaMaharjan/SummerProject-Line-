import 'package:flutter/material.dart';
import 'package:major/config/supabase_config.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../models/service.dart';
import '../home/home_screen.dart';

class TokenConfirmationScreen extends StatefulWidget {
  final Service service;

  const TokenConfirmationScreen({
    super.key,
    required this.service,
  });

  @override
  State<TokenConfirmationScreen> createState() => _TokenConfirmationScreenState();
}

class _TokenConfirmationScreenState extends State<TokenConfirmationScreen> {
  bool _isBooking = false;
  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();

  Future<void> _selectDate(BuildContext context) async {
    try {
      debugPrint('Opening date picker...');
      
      final DateTime today = DateTime.now();
      final DateTime initialDate = _selectedDate ?? today;
      
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        helpText: 'Select appointment date',
        cancelText: 'Cancel',
        confirmText: 'Select',
        selectableDayPredicate: (DateTime date) {
          final DateTime today = DateTime.now();
          final bool isToday = date.year == today.year && 
                              date.month == today.month && 
                              date.day == today.day;
          
          // Allow today as exception, otherwise disable weekends
          if (isToday) {
            return true; // Allow today even if it's weekend
          }
          
          // Disable weekends for other dates
          if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
            return false;
          }
          return true;
        },
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue.shade600,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (picked != null) {
        debugPrint('Date selected: $picked');
        setState(() {
          _selectedDate = picked;
          _dateController.text = _formatDate(picked);
        });
        debugPrint('Date state updated successfully');
      } else {
        debugPrint('Date picker cancelled');
      }
    } catch (e) {
      debugPrint('Error showing date picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening date picker: ${e.toString()}'),
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
        title: const Text('Confirm Booking'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getServiceIcon(widget.service.type),
                            color: Colors.blue.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.service.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.service.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.service.description!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Service Details
                    _buildDetailRow(
                      icon: Icons.access_time,
                      label: 'Estimated Time',
                      value: '${widget.service.estimatedTimeMinutes} minutes',
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: _formatDate(DateTime.now()),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      icon: Icons.room,
                      label: 'Starting Room',
                      value: 'Reception (R001)',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Date Selection
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Select Date',
                hintText: 'Tap to select date',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (_selectedDate == null) {
                  return 'Please select a date';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Important Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Please arrive 10 minutes before your estimated time\n'
                    '• Bring all required documents\n'
                    '• You will receive notifications about your queue status\n'
                    '• Token is valid only for today',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Book Token Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _bookToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isBooking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Book Token',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isBooking ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _getServiceIcon(ServiceType type) {
    switch (type) {
      case ServiceType.licenseRenewal:
        return Icons.refresh;
      case ServiceType.newLicense:
        return Icons.add_card;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _bookToken() async {
    if (!mounted) return;
    
    setState(() => _isBooking = true);

    try {
      // Validate date selection
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date')),
        );
        setState(() => _isBooking = false);
        return;
      }

      final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
      
      // Format the date to YYYY-MM-DD for storage
      final formattedDate = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      
      // Get the default reception room
      var receptionRoom = await SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('room_number', 'R001')
          .maybeSingle();

      // If reception room not found, create it
      if (receptionRoom == null) {
        receptionRoom = await SupabaseConfig.client
            .from('rooms')
            .insert({
              'name': 'Reception',
              'room_number': 'R001',
              'is_active': true,
            })
            .select()
            .single();
      }

      // Create the token
      final success = await tokenProvider.createToken(
        serviceId: widget.service.id,
        serviceName: widget.service.name,
        estimatedWaitTime: widget.service.estimatedTimeMinutes,
        roomId: receptionRoom['id'],
        roomName: receptionRoom['name'],
        scheduledDate: formattedDate,
      );

      if (!mounted) return;
      
      setState(() => _isBooking = false);
      
      if (success) {
        // Show success dialog
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Booking Confirmed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Token Booked Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your token has been added to the queue for ${_formatDate(_selectedDate!)}. You can track its status in the "My Tokens" tab.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Show error message from provider
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tokenProvider.errorMessage ?? 'Failed to create token'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
