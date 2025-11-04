import 'dart:async';
import 'package:flutter/material.dart';
import '../models/token.dart';
import '../services/queue_estimation_service.dart';
import '../services/nepali_calendar_service.dart';

/// Widget that displays queue estimation and wait time
class QueueEstimationWidget extends StatefulWidget {
  final Token token;
  
  const QueueEstimationWidget({
    super.key,
    required this.token,
  });
  
  @override
  State<QueueEstimationWidget> createState() => _QueueEstimationWidgetState();
}

class _QueueEstimationWidgetState extends State<QueueEstimationWidget> {
  final _queueService = QueueEstimationService();
  final _nepaliCalendar = NepaliCalendarService();
  EnhancedQueueInfo? _enhancedInfo;
  bool _isLoading = true;
  Timer? _autoRefreshTimer;
  Timer? _countdownTimer;
  int _remainingMinutes = 0;
  DateTime? _countdownStartTime;
  
  @override
  void initState() {
    super.initState();
    _loadQueueInfo();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Auto-refresh every 1 minute if real-time tracking is active
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && widget.token.status == TokenStatus.waiting) {
        final canShowRealTime = _queueService.canShowRealTimeTracking(widget.token);
        if (canShowRealTime) {
          _loadQueueInfo();
        } else {
          // Stop auto-refresh if not during office hours
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }
  
  Future<void> _loadQueueInfo() async {
    if (widget.token.status == TokenStatus.waiting) {
      final enhancedInfo = await _queueService.getEnhancedQueueInfo(widget.token);
      if (mounted) {
        setState(() {
          _enhancedInfo = enhancedInfo;
          _isLoading = false;
          
          // Initialize countdown if real-time tracking is active
          if (enhancedInfo.showRealTimeEstimation) {
            // Use real-time countdown that considers currently processing tokens
            _remainingMinutes = enhancedInfo.realTimeCountdownMinutes;
            _countdownStartTime = DateTime.now();
            _startCountdown();
          } else {
            _countdownTimer?.cancel();
          }
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    
    // Check queue status every minute (don't just decrease time)
    // The countdown should only decrease when queue actually moves
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        // Refresh queue data to get actual position
        // This will recalculate the wait time based on current queue
        _loadQueueInfo();
      } else {
        timer.cancel();
      }
    });
  }

  String _formatCountdownTime() {
    if (_remainingMinutes <= 0) {
      return 'Your turn is coming up!';
    } else if (_remainingMinutes == 1) {
      return '~1 minute';
    } else if (_remainingMinutes < 60) {
      return '~$_remainingMinutes minutes';
    } else {
      final hours = (_remainingMinutes / 60).floor();
      final minutes = _remainingMinutes % 60;
      if (minutes == 0) {
        return '~$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '~$hours ${hours == 1 ? 'hour' : 'hours'} $minutes min';
      }
    }
  }

  DateTime? _getEstimatedCompletionTime() {
    if (_remainingMinutes <= 0 || _countdownStartTime == null) {
      return null;
    }
    return _countdownStartTime!.add(Duration(minutes: _remainingMinutes));
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.token.status != TokenStatus.waiting) {
      return const SizedBox.shrink(); // Don't show for non-waiting tokens
    }
    
    if (_isLoading) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(
                'Calculating wait time...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_enhancedInfo == null) {
      return const SizedBox.shrink();
    }

    final queueInfo = _enhancedInfo!.queueInfo;
    final showRealTime = _enhancedInfo!.showRealTimeEstimation;
    
    return Card(
      elevation: 2,
      color: showRealTime ? Colors.blue.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status indicator
            Row(
              children: [
                Icon(
                  showRealTime ? Icons.live_tv : Icons.schedule,
                  color: showRealTime ? Colors.red : Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            showRealTime ? 'LIVE Tracking' : 'Queue Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: showRealTime ? Colors.blue.shade900 : Colors.orange.shade900,
                            ),
                          ),
                          if (showRealTime) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LIVE',
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
                      const SizedBox(height: 4),
                      Text(
                        _enhancedInfo!.displayMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Appointment date info
            if (widget.token.scheduledDate != null) ...[
              _buildInfoRow(
                Icons.calendar_today,
                'Appointment Date',
                _nepaliCalendar.formatDateWithNepali(widget.token.scheduledDate!),
              ),
              const SizedBox(height: 8),
            ],
            
            // Queue position
            _buildInfoRow(
              Icons.format_list_numbered,
              'Queue Position',
              queueInfo.positionText,
            ),
            
            const SizedBox(height: 8),
            
            // Tokens ahead
            _buildInfoRow(
              Icons.people_outline,
              'People Ahead',
              queueInfo.tokensAheadText,
            ),
            
            // Show estimation only if real-time tracking is active
            if (showRealTime) ...[
              const SizedBox(height: 8),
              
              // Average handling time
              _buildInfoRow(
                Icons.timer_outlined,
                'Avg. Service Time',
                '~${queueInfo.averageHandlingTimeMinutes} minutes',
              ),
              
              const SizedBox(height: 16),
              
              // Live countdown timer (large display)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, color: Colors.blue.shade700, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          _formatCountdownTime(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (_remainingMinutes > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_down, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Counting down...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            if (showRealTime && _remainingMinutes > 0) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              
              // Estimated completion time (using countdown)
              Row(
                children: [
                  Icon(Icons.schedule, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Expected around ',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _queueService.formatCompletionTime(_getEstimatedCompletionTime()),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Refresh button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadQueueInfo();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }
}
