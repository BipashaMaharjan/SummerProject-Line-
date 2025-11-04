import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/token.dart';

/// Simplified token tracker that fetches data directly
class SimpleTokenTracker extends StatefulWidget {
  final Token token;
  
  const SimpleTokenTracker({
    super.key,
    required this.token,
  });
  
  @override
  State<SimpleTokenTracker> createState() => _SimpleTokenTrackerState();
}

class _SimpleTokenTrackerState extends State<SimpleTokenTracker> {
  Token? _currentToken;
  bool _isLoading = true;
  String? _error;
  int _queuePosition = 0;
  int _tokensAhead = 0;
  
  @override
  void initState() {
    super.initState();
    _loadTokenData();
    _setupRealtimeListener();
  }
  
  Future<void> _loadTokenData() async {
    try {
      debugPrint('SimpleTokenTracker: Loading token data for ID: ${widget.token.id}');
      
      // Fetch fresh token data
      final tokenData = await SupabaseConfig.client
          .from('tokens')
          .select()
          .eq('id', widget.token.id)
          .single();
      
      debugPrint('SimpleTokenTracker: Token data fetched: $tokenData');
      
      // Fetch service name
      String? serviceName;
      try {
        final serviceData = await SupabaseConfig.client
            .from('services')
            .select('name')
            .eq('id', tokenData['service_id'])
            .single();
        serviceName = serviceData['name'];
      } catch (e) {
        debugPrint('SimpleTokenTracker: Error fetching service: $e');
      }
      
      // Fetch room info if available
      String? roomName;
      String? roomNumber;
      if (tokenData['current_room_id'] != null) {
        try {
          final roomData = await SupabaseConfig.client
              .from('rooms')
              .select('name, room_number')
              .eq('id', tokenData['current_room_id'])
              .single();
          roomName = roomData['name'];
          roomNumber = roomData['room_number'];
        } catch (e) {
          debugPrint('SimpleTokenTracker: Error fetching room: $e');
        }
      }
      
      // Calculate queue position
      if (tokenData['status'] == 'waiting') {
        try {
          final queueData = await SupabaseConfig.client
              .from('tokens')
              .select('id')
              .eq('service_id', tokenData['service_id'])
              .eq('status', 'waiting')
              .lt('created_at', tokenData['created_at']);
          
          _tokensAhead = (queueData as List).length;
          _queuePosition = _tokensAhead + 1;
        } catch (e) {
          debugPrint('SimpleTokenTracker: Error calculating queue: $e');
        }
      }
      
      // Build complete token data
      final completeTokenData = Map<String, dynamic>.from(tokenData);
      completeTokenData['service_name'] = serviceName;
      completeTokenData['current_room_name'] = roomName;
      completeTokenData['current_room_number'] = roomNumber;
      
      if (mounted) {
        setState(() {
          _currentToken = Token.fromJson(completeTokenData);
          _isLoading = false;
          _error = null;
        });
      }
      
      debugPrint('SimpleTokenTracker: Token loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('SimpleTokenTracker: Error loading token: $e');
      debugPrint('SimpleTokenTracker: Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _error = 'Failed to load token data: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  void _setupRealtimeListener() {
    try {
      SupabaseConfig.client
          .channel('token_${widget.token.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tokens',
            callback: (payload) {
              debugPrint('SimpleTokenTracker: Received update: ${payload.newRecord}');
              // Only reload if it's our token
              if (payload.newRecord['id'] == widget.token.id) {
                _loadTokenData();
              }
            },
          )
          .subscribe();
      
      debugPrint('SimpleTokenTracker: Realtime listener setup complete');
    } catch (e) {
      debugPrint('SimpleTokenTracker: Error setting up realtime: $e');
      // Continue without realtime - user can still manually refresh
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error Loading Token',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Token ID: ${widget.token.id}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadTokenData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  debugPrint('=== DEBUG INFO ===');
                  debugPrint('Token ID: ${widget.token.id}');
                  debugPrint('Token Number: ${widget.token.tokenNumber}');
                  debugPrint('Service ID: ${widget.token.serviceId}');
                  debugPrint('Status: ${widget.token.status}');
                  debugPrint('==================');
                },
                child: const Text('Print Debug Info'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_currentToken == null) {
      return const Center(
        child: Text('No token data available'),
      );
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTokenCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            if (_currentToken!.status == TokenStatus.waiting) ...[
              const SizedBox(height: 16),
              _buildQueueCard(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildTokenCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token: ${_currentToken!.displayToken}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentToken!.serviceName ?? 'Service',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge() {
    final status = _currentToken!.status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.statusColor, width: 1),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: status.statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      color: _currentToken!.status.statusColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _getStatusIcon(),
              color: _currentToken!.status.statusColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusTitle(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusMessage(),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Live',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQueueCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Queue Information',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.people_outline, 'Queue Position', '#$_queuePosition'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.queue, 'Tokens Ahead', '$_tokensAhead'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  IconData _getStatusIcon() {
    switch (_currentToken!.status) {
      case TokenStatus.waiting:
        return Icons.hourglass_empty;
      case TokenStatus.hold:
        return Icons.pause_circle_outline;
      case TokenStatus.processing:
        return Icons.play_circle_outline;
      case TokenStatus.completed:
        return Icons.check_circle_outline;
      case TokenStatus.rejected:
        return Icons.cancel_outlined;
      case TokenStatus.noShow:
        return Icons.person_off_outlined;
    }
  }
  
  String _getStatusTitle() {
    switch (_currentToken!.status) {
      case TokenStatus.waiting:
        return 'Waiting in Queue';
      case TokenStatus.hold:
        return 'On Hold';
      case TokenStatus.processing:
        return 'Being Processed';
      case TokenStatus.completed:
        return 'Completed';
      case TokenStatus.rejected:
        return 'Rejected';
      case TokenStatus.noShow:
        return 'No Show';
    }
  }
  
  String _getStatusMessage() {
    switch (_currentToken!.status) {
      case TokenStatus.waiting:
        return 'You are #$_queuePosition in queue. $_tokensAhead tokens ahead.';
      case TokenStatus.hold:
        return 'Your token is on hold. Please wait for further instructions.';
      case TokenStatus.processing:
        if (_currentToken!.currentRoomName != null) {
          return 'Being served in ${_currentToken!.currentRoomName} (${_currentToken!.currentRoomNumber ?? 'N/A'})';
        }
        return 'Your token is being processed';
      case TokenStatus.completed:
        return 'Service completed successfully';
      case TokenStatus.rejected:
        return 'Token was rejected. Please contact staff.';
      case TokenStatus.noShow:
        return 'Token marked as no-show';
    }
  }
}
