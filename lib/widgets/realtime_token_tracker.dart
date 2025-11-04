import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/realtime_tracking_service.dart';
import '../models/token.dart';

/// Widget that displays real-time token tracking information
class RealtimeTokenTracker extends StatefulWidget {
  final String tokenId;
  final bool showDetailedInfo;
  
  const RealtimeTokenTracker({
    super.key,
    required this.tokenId,
    this.showDetailedInfo = true,
  });
  
  @override
  State<RealtimeTokenTracker> createState() => _RealtimeTokenTrackerState();
}

class _RealtimeTokenTrackerState extends State<RealtimeTokenTracker> {
  final _trackingService = RealtimeTrackingService();
  TokenTrackingInfo? _trackingInfo;
  StreamSubscription<Token>? _tokenSubscription;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }
  
  Future<void> _initializeTracking() async {
    try {
      debugPrint('RealtimeTokenTracker: Initializing tracking for token: ${widget.tokenId}');
      
      // Initialize the service
      await _trackingService.initialize();
      debugPrint('RealtimeTokenTracker: Service initialized');
      
      // Load initial tracking info
      await _loadTrackingInfo();
      debugPrint('RealtimeTokenTracker: Initial tracking info loaded');
      
      // Subscribe to real-time updates
      _tokenSubscription = _trackingService
          .subscribeToToken(widget.tokenId)
          .listen((token) {
        debugPrint('RealtimeTokenTracker: Received token update: ${token.tokenNumber}');
        _loadTrackingInfo();
      });
      
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('RealtimeTokenTracker: Error initializing: $e');
      debugPrint('RealtimeTokenTracker: Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to initialize tracking: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadTrackingInfo() async {
    try {
      debugPrint('RealtimeTokenTracker: Loading tracking info for token: ${widget.tokenId}');
      final info = await _trackingService.getTokenTrackingInfo(widget.tokenId);
      debugPrint('RealtimeTokenTracker: Tracking info result: ${info != null ? "success" : "null"}');
      
      if (mounted) {
        setState(() {
          _trackingInfo = info;
          if (info == null) {
            _error = 'No tracking information available. Token ID: ${widget.tokenId}';
          } else {
            _error = null;
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('RealtimeTokenTracker: Error loading tracking info: $e');
      debugPrint('RealtimeTokenTracker: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load tracking info: $e';
        });
      }
    }
  }
  
  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initializeTracking();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_trackingInfo == null) {
      return const Center(
        child: Text('No tracking information available'),
      );
    }
    
    return _buildTrackingCard();
  }
  
  Widget _buildTrackingCard() {
    final info = _trackingInfo!;
    final token = info.token;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with token number and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token: ${token.displayToken}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      token.serviceName ?? 'Service',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(token.status),
              ],
            ),
            
            const Divider(height: 24),
            
            // Status message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusBackgroundColor(token.status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(token.status),
                    color: token.statusColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      info.statusMessage,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            if (widget.showDetailedInfo) ...[
              const SizedBox(height: 16),
              _buildDetailedInfo(info),
            ],
            
            // Last updated timestamp
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Last updated: ${_formatTime(info.lastUpdated)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Live',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailedInfo(TokenTrackingInfo info) {
    return Column(
      children: [
        if (info.token.status == TokenStatus.waiting) ...[
          _buildInfoRow(
            icon: Icons.people_outline,
            label: 'Queue Position',
            value: '#${info.queuePosition}',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.queue,
            label: 'Tokens Ahead',
            value: '${info.tokensAhead}',
          ),
        ],
        
        if (info.currentRoomInfo != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.room,
            label: 'Current Room',
            value: '${info.currentRoomInfo!.roomName} (${info.currentRoomInfo!.roomNumber})',
          ),
        ],
        
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.calendar_today,
          label: 'Booked At',
          value: _formatDateTime(info.token.bookedAt ?? info.token.createdAt),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusBadge(TokenStatus status) {
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
  
  Color _getStatusBackgroundColor(TokenStatus status) {
    return status.statusColor.withOpacity(0.05);
  }
  
  IconData _getStatusIcon(TokenStatus status) {
    switch (status) {
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
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
