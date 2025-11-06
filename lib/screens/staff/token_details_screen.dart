import 'package:flutter/material.dart';
import '../../models/token.dart';
import '../../config/supabase_config.dart';

class TokenDetailsScreen extends StatefulWidget {
  final Token token;

  const TokenDetailsScreen({super.key, required this.token});

  @override
  State<TokenDetailsScreen> createState() => _TokenDetailsScreenState();
}

class _TokenDetailsScreenState extends State<TokenDetailsScreen> {
  List<Map<String, dynamic>> _workflow = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkflowAndHistory();
  }

  Future<void> _loadWorkflowAndHistory() async {
    try {
      debugPrint('🔍 Loading workflow for service: ${widget.token.serviceId}');
      
      // Load service workflow - EXPLICITLY order ascending
      final workflowResponse = await SupabaseConfig.client
          .from('service_workflow')
          .select('*, room:rooms(name, room_number)')
          .eq('service_id', widget.token.serviceId)
          .order('sequence_order', ascending: true);  // Explicitly ascending

      debugPrint('📋 Workflow response: $workflowResponse');
      debugPrint('📋 Workflow count: ${(workflowResponse as List).length}');

      // Convert to list and check order
      var workflowList = List<Map<String, dynamic>>.from(workflowResponse as List);
      
      // Debug: Print first and last sequence to verify order
      if (workflowList.isNotEmpty) {
        debugPrint('📋 First sequence: ${workflowList.first['sequence_order']}');
        debugPrint('📋 Last sequence: ${workflowList.last['sequence_order']}');
        
        // If first sequence is greater than last, the list is reversed - fix it!
        if (workflowList.first['sequence_order'] > workflowList.last['sequence_order']) {
          debugPrint('⚠️ Workflow is reversed! Fixing order...');
          workflowList = workflowList.reversed.toList();
          debugPrint('✅ Workflow order corrected');
        }
      }

      // Load token history (if table exists)
      List<dynamic> historyResponse = [];
      try {
        historyResponse = await SupabaseConfig.client
            .from('token_history')
            .select('*')
            .eq('token_id', widget.token.id)
            .order('created_at', ascending: false);  // Use created_at instead of timestamp
      } catch (e) {
        debugPrint('⚠️ Could not load history: $e');
        // History is optional, continue without it
      }

      debugPrint('📜 History response: $historyResponse');

      setState(() {
        _workflow = workflowList;  // Use the corrected list
        _history = List<Map<String, dynamic>>.from(historyResponse);
        _loading = false;
      });
      
      if (_workflow.isEmpty) {
        debugPrint('⚠️ No workflow found for service: ${widget.token.serviceId}');
      } else {
        debugPrint('✅ Loaded ${_workflow.length} workflow steps');
      }
    } catch (e) {
      debugPrint('❌ Error loading workflow: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Token ${widget.token.displayToken}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkflowAndHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Token Info Card
                  _TokenInfoCard(token: widget.token),
                  const SizedBox(height: 16),
                  
                  // Workflow Progress
                  _WorkflowProgress(
                    workflow: _workflow,
                    currentRoomId: widget.token.currentRoomId,
                    currentSequence: widget.token.currentSequence,
                  ),
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  if (widget.token.status == TokenStatus.processing)
                    _ActionSection(
                      token: widget.token,
                      workflow: _workflow,
                      onComplete: () {
                        Navigator.pop(context);
                      },
                    ),
                  const SizedBox(height: 16),
                  
                  // History
                  _HistorySection(history: _history),
                ],
              ),
            ),
    );
  }
}

class _TokenInfoCard extends StatelessWidget {
  final Token token;

  const _TokenInfoCard({required this.token});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: token.statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    token.displayToken,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: token.statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: token.statusColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    token.statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(icon: Icons.person, label: 'Customer', value: token.userName ?? 'N/A'),
            _InfoRow(icon: Icons.room_service, label: 'Service', value: token.serviceName ?? 'N/A'),
            _InfoRow(icon: Icons.room, label: 'Current Room', value: '${token.currentRoomName ?? "N/A"} (${token.currentRoomNumber ?? ""})'),
            if (token.queuePosition != null)
              _InfoRow(icon: Icons.people, label: 'Queue Position', value: token.queuePosition.toString()),
            _InfoRow(icon: Icons.access_time, label: 'Booked At', value: _formatTime(token.bookedAt)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'N/A';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowProgress extends StatelessWidget {
  final List<Map<String, dynamic>> workflow;
  final String? currentRoomId;
  final int? currentSequence;

  const _WorkflowProgress({
    required this.workflow,
    required this.currentRoomId,
    required this.currentSequence,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workflow Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (workflow.isEmpty)
              const Text('No workflow defined')
            else
              ...workflow.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final room = step['room'];
                final isCurrentRoom = step['room_id'] == currentRoomId;
                final isPastRoom = (step['sequence_order'] as int) < (currentSequence ?? 0);
                
                return _WorkflowStep(
                  roomName: room['name'],
                  roomNumber: room['room_number'],
                  sequenceOrder: step['sequence_order'],
                  isCurrentRoom: isCurrentRoom,
                  isPastRoom: isPastRoom,
                  isLastStep: index == workflow.length - 1,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  final String roomName;
  final String roomNumber;
  final int sequenceOrder;
  final bool isCurrentRoom;
  final bool isPastRoom;
  final bool isLastStep;

  const _WorkflowStep({
    required this.roomName,
    required this.roomNumber,
    required this.sequenceOrder,
    required this.isCurrentRoom,
    required this.isPastRoom,
    required this.isLastStep,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (isCurrentRoom) color = Colors.blue;
    if (isPastRoom) color = Colors.green;

    return Column(
      children: [
        Row(
          children: [
            // Step indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: isPastRoom
                    ? Icon(Icons.check, color: color, size: 20)
                    : Text(
                        sequenceOrder.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Room info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomName,
                    style: TextStyle(
                      fontWeight: isCurrentRoom ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    roomNumber,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            // Current indicator
            if (isCurrentRoom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        if (!isLastStep)
          Container(
            margin: const EdgeInsets.only(left: 19),
            width: 2,
            height: 30,
            color: isPastRoom ? Colors.green : Colors.grey[300],
          ),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  final Token token;
  final List<Map<String, dynamic>> workflow;
  final VoidCallback onComplete;

  const _ActionSection({
    required this.token,
    required this.workflow,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Find current room index
    final currentIndex = workflow.indexWhere(
      (step) => step['room_id'] == token.currentRoomId,
    );

    debugPrint('🔍 Action Section Debug:');
    debugPrint('  - Workflow length: ${workflow.length}');
    debugPrint('  - Current room ID: ${token.currentRoomId}');
    debugPrint('  - Current index: $currentIndex');
    debugPrint('  - Current sequence: ${token.currentSequence}');

    final isLastRoom = currentIndex >= 0 && currentIndex >= workflow.length - 1;
    final hasNextRoom = currentIndex >= 0 && currentIndex < workflow.length - 1;
    final nextRoom = hasNextRoom ? workflow[currentIndex + 1]['room'] : null;

    debugPrint('  - Is last room: $isLastRoom');
    debugPrint('  - Has next room: $hasNextRoom');
    debugPrint('  - Next room: ${nextRoom?['name']}');

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // PRIMARY ACTION: Transfer button (full width, prominent)
            if (hasNextRoom && nextRoom != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 24),
                  label: Text(
                    'Transfer to ${nextRoom['name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    elevation: 2,
                  ),
                  onPressed: () => _transferToNextRoom(context, nextRoom),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // SECONDARY ACTIONS: Hold, Reject, and Complete
            Row(
              children: [
                // Hold button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Hold'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.all(14),
                      side: const BorderSide(color: Colors.orange, width: 1.5),
                    ),
                    onPressed: () => _holdToken(context),
                  ),
                ),
                const SizedBox(width: 8),
                // Reject button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.all(14),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    onPressed: () => _rejectToken(context),
                  ),
                ),
                const SizedBox(width: 8),
                // Complete button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastRoom ? Colors.green : Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => _completeToken(context),
                  ),
                ),
              ],
            ),
            
            // Debug info - ALWAYS SHOW for troubleshooting
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Workflow Status',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    
                    // Show complete workflow
                    if (workflow.isNotEmpty)
                      ...workflow.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final step = entry.value;
                        final room = step['room'];
                        final isCurrent = idx == currentIndex;
                        final isPast = idx < currentIndex;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isCurrent 
                                      ? Colors.blue 
                                      : isPast 
                                          ? Colors.green 
                                          : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      color: (isCurrent || isPast) ? Colors.white : Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  room['name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? Colors.blue.shade900 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'YOU ARE HERE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    
                    const Divider(height: 16),
                    
                    // Summary
                    if (hasNextRoom && nextRoom != null)
                      Row(
                        children: [
                          Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Next: ${nextRoom['name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (!hasNextRoom && currentIndex >= 0)
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Last room - Ready to complete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Error: Current room not found in workflow',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transferToNextRoom(BuildContext context, Map<String, dynamic> nextRoom) async {
    try {
      debugPrint('🔄 ========== TOKEN TRANSFER STARTED ==========');
      debugPrint('📋 Token ID: ${token.id}');
      debugPrint('📋 Token Number: ${token.displayToken}');
      debugPrint('📍 Current Room: ${token.currentRoomName} (${token.currentRoomId})');
      debugPrint('📍 Next Room: ${nextRoom['name']} (${nextRoom['room_number']})');
      
      final currentIndex = workflow.indexWhere(
        (step) => step['room_id'] == token.currentRoomId,
      );
      final nextStep = workflow[currentIndex + 1];
      final timestamp = DateTime.now().toIso8601String();

      debugPrint('🔄 Fetching next room staff...');
      
      // Get staff assigned to next room
      String? nextRoomStaffId;
      String? nextRoomStaffName;
      try {
        final nextRoomStaffResponse = await SupabaseConfig.client
            .rpc('get_room_staff', params: {'room_uuid': nextStep['room_id']});
        
        if (nextRoomStaffResponse != null && nextRoomStaffResponse is List && nextRoomStaffResponse.isNotEmpty) {
          nextRoomStaffId = nextRoomStaffResponse[0]['staff_id'];
          nextRoomStaffName = nextRoomStaffResponse[0]['staff_name'];
          debugPrint('👤 Next room staff: $nextRoomStaffName ($nextRoomStaffId)');
        } else {
          debugPrint('⚠️ No staff assigned to next room');
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch room staff: $e');
      }

      debugPrint('🔄 Updating token in database...');
      
      // Update token with all necessary fields for real-time sync
      await SupabaseConfig.client.from('tokens').update({
        'current_room_id': nextStep['room_id'],
        'current_sequence': nextStep['sequence_order'],
        'status': 'waiting', // Reset to waiting for next room
        'assigned_staff_id': nextRoomStaffId, // Auto-assign to next room's staff
        'updated_at': timestamp,
        'started_at': null, // Clear started_at for new room
      }).eq('id', token.id);

      debugPrint('✅ Token updated in database');
      debugPrint('📝 Recording transfer in history...');

      // Record transfer in history (using only existing columns)
      await SupabaseConfig.client.from('token_history').insert({
        'token_id': token.id,
        'room_id': nextStep['room_id'],  // New room
        'action': 'transferred',
        'status': 'waiting',
        'notes': 'Transferred from ${token.currentRoomName ?? "previous room"} to ${nextRoom['name']}',
        'performed_by': SupabaseConfig.client.auth.currentUser?.id,
      });

      debugPrint('✅ Transfer recorded in history');
      
      // Create notification for next room's staff
      if (nextRoomStaffId != null) {
        await SupabaseConfig.client.from('staff_notifications').insert({
          'staff_id': nextRoomStaffId,
          'token_id': token.id,
          'message': 'New ticket received — Token #${token.displayToken} has been assigned to you.',
          'type': 'assigned',
        });
        debugPrint('📬 Notification sent to next room staff');
      }
      
      debugPrint('🔔 Real-time update triggered automatically by Supabase');
      debugPrint('📡 All connected dashboards will receive update');
      debugPrint('✅ ========== TOKEN TRANSFER COMPLETED ==========');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextRoomStaffName != null
                        ? '✅ Ticket successfully transferred to ${nextRoom['name']}\nAssigned to: $nextRoomStaffName'
                        : '✅ Ticket successfully transferred to ${nextRoom['name']}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Close the details screen and return to dashboard
        // The dashboard will automatically refresh via Supabase real-time
        onComplete();
      }
    } catch (e) {
      debugPrint('❌ ========== TOKEN TRANSFER FAILED ==========');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Failed to transfer: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _holdToken(BuildContext context) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hold Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Put this token on hold temporarily?'),
            const SizedBox(height: 8),
            const Text(
              'The customer can resume when ready.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Customer stepped out',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Hold'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final reason = reasonController.text.trim().isEmpty
            ? 'Put on hold by staff'
            : reasonController.text.trim();

        await SupabaseConfig.client.from('tokens').update({
          'status': 'hold',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', token.id);

        await SupabaseConfig.client.from('token_history').insert({
          'token_id': token.id,
          'room_id': token.currentRoomId,
          'status': 'hold',
          'action': 'hold',
          'notes': reason,
          'performed_by': SupabaseConfig.client.auth.currentUser?.id,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.pause_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('⏸️ Token put on hold')),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
          onComplete();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Failed to hold token: $e')),
          );
        }
      }
    }

    reasonController.dispose();
  }

  Future<void> _rejectToken(BuildContext context) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to reject this token?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final reason = reasonController.text.trim().isEmpty 
            ? 'Rejected by staff' 
            : reasonController.text.trim();

        await SupabaseConfig.client.from('tokens').update({
          'status': 'rejected',
          'completed_at': DateTime.now().toIso8601String(),
        }).eq('id', token.id);

        await SupabaseConfig.client.from('token_history').insert({
          'token_id': token.id,
          'room_id': token.currentRoomId,
          'status': 'rejected',
          'action': 'rejected',
          'notes': reason,
          'performed_by': SupabaseConfig.client.auth.currentUser?.id,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Token rejected'),
              backgroundColor: Colors.red,
            ),
          );
          onComplete();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Failed to reject: $e')),
          );
        }
      }
    }
    
    reasonController.dispose();
  }

  Future<void> _completeToken(BuildContext context) async {
    try {
      await SupabaseConfig.client.from('tokens').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', token.id);

      await SupabaseConfig.client.from('token_history').insert({
        'token_id': token.id,
        'room_id': token.currentRoomId,
        'status': 'completed',
        'action': 'completed',
        'notes': 'Completed by staff',
        'performed_by': SupabaseConfig.client.auth.currentUser?.id,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Token completed successfully')),
        );
        onComplete();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to complete: $e')),
        );
      }
    }
  }
}

class _HistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _HistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Text('No history available')
            else
              ...history.map((entry) {
                final action = entry['action'];
                final notes = entry['notes'];
                final createdAt = DateTime.parse(entry['created_at']);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _getActionIcon(action),
                        size: 20,
                        color: _getActionColor(action),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notes ?? action,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle;
      case 'transferred':
        return Icons.arrow_forward;
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'created':
        return Colors.blue;
      case 'transferred':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
