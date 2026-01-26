import 'package:flutter/material.dart';
import '../services/queue_status_service.dart';

/// Widget to display currently serving token in real-time
/// Shows "Now Serving: [Token Number]" with live updates
class QueueStatusWidget extends StatefulWidget {
  final String serviceId;
  final bool showLabel;
  final TextStyle? tokenStyle;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const QueueStatusWidget({
    Key? key,
    required this.serviceId,
    this.showLabel = true,
    this.tokenStyle,
    this.backgroundColor,
    this.padding,
  }) : super(key: key);

  @override
  State<QueueStatusWidget> createState() => _QueueStatusWidgetState();
}

class _QueueStatusWidgetState extends State<QueueStatusWidget>
    with SingleTickerProviderStateMixin {
  final QueueStatusService _queueService = QueueStatusService();
  QueueStatus? _currentStatus;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for active indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QueueStatus>(
      stream: _queueService.subscribeToQueueUpdates(widget.serviceId)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: (sink) {
              // After 3 seconds of no data, show empty state
              sink.add(QueueStatus(
                id: 'timeout',
                serviceId: widget.serviceId,
                currentTokenNumber: null,
                updatedAt: DateTime.now(),
              ));
            },
          ),
      builder: (context, snapshot) {
        // Show error if connection failed
        if (snapshot.hasError) {
          debugPrint('QueueStatusWidget Error: ${snapshot.error}');
          return _buildNoTokenState(); // Show empty instead of error
        }

        // Show loading only briefly
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        // If we have data but token is null, show "no token serving"
        if (snapshot.hasData) {
          final status = snapshot.data!;
          _currentStatus = status;

          if (status.currentTokenNumber == null) {
            return _buildNoTokenState();
          }

          return _buildActiveState(status);
        }

        // Default: no token being served
        return _buildNoTokenState();
      },
    );
  }

  Widget _buildActiveState(QueueStatus status) {
    return Container(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated pulse indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(_pulseAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(_pulseAnimation.value * 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          
          // Label and token number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showLabel)
                Text(
                  'Now Serving',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (widget.showLabel) const SizedBox(height: 2),
              Text(
                status.currentTokenNumber!,
                style: widget.tokenStyle ??
                    TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          
          const SizedBox(width: 8),
          
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTokenState() {
    return Container(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Text(
            'No token currently being served',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading queue status...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Text(
            'Unable to load queue status',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for smaller spaces
class CompactQueueStatusWidget extends StatelessWidget {
  final String serviceId;

  const CompactQueueStatusWidget({
    Key? key,
    required this.serviceId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return QueueStatusWidget(
      serviceId: serviceId,
      showLabel: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tokenStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    );
  }
}
