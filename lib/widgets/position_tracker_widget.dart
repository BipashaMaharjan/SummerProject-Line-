import 'dart:async';
import 'package:flutter/material.dart';
import '../services/queue_status_service.dart';

/// Real-time Position Tracker Widget
/// Shows user's current position with visual feedback when it changes
class PositionTrackerWidget extends StatefulWidget {
  final String tokenId;
  final String serviceId;

  const PositionTrackerWidget({
    Key? key,
    required this.tokenId,
    required this.serviceId,
  }) : super(key: key);

  @override
  State<PositionTrackerWidget> createState() => _PositionTrackerWidgetState();
}

class _PositionTrackerWidgetState extends State<PositionTrackerWidget>
    with SingleTickerProviderStateMixin {
  final QueueStatusService _queueService = QueueStatusService();
  int? _currentPosition;
  int? _previousPosition;
  Timer? _refreshTimer;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.green,
    ).animate(_animationController);
    
    _loadPosition();
    
    // Refresh position every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadPosition();
    });
  }

  @override
  void dispose() {
    // ✅ FIX: Clean up all resources to prevent memory leak
    _refreshTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    try {
      final position = await _queueService.calculateQueuePosition(widget.tokenId);
      
      if (mounted && position != _currentPosition) {
        setState(() {
          _previousPosition = _currentPosition;
          _currentPosition = position;
          
          // Animate if position improved (moved up in queue)
          if (_previousPosition != null && 
              position < _previousPosition! && 
              position > 0) {
            _animationController.forward(from: 0);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading position: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null || _currentPosition == 0) {
      return const SizedBox.shrink();
    }

    final hasImproved = _previousPosition != null && 
                        _currentPosition! < _previousPosition!;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: hasImproved ? _scaleAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasImproved && _animationController.isAnimating
                    ? [_colorAnimation.value!, _colorAnimation.value!.withOpacity(0.7)]
                    : [Colors.blue.shade700, Colors.blue.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (hasImproved && _animationController.isAnimating
                          ? Colors.green
                          : Colors.blue)
                      .withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Position indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getPositionIcon(),
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Position',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '#$_currentPosition',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Movement indicator
                if (hasImproved && _animationController.isAnimating) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Moved up ${_previousPosition! - _currentPosition!} ${_previousPosition! - _currentPosition! == 1 ? 'position' : 'positions'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Status message
                const SizedBox(height: 12),
                Text(
                  _getStatusMessage(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getPositionIcon() {
    if (_currentPosition! <= 2) {
      return Icons.notifications_active;
    } else if (_currentPosition! <= 5) {
      return Icons.schedule;
    } else {
      return Icons.hourglass_bottom;
    }
  }

  String _getStatusMessage() {
    if (_currentPosition! == 1) {
      return '🎯 You\'re next! Please be ready.';
    } else if (_currentPosition! == 2) {
      return '⚠️ Almost your turn! 2 positions away.';
    } else if (_currentPosition! <= 5) {
      return '⏰ Your turn is coming soon.';
    } else {
      return '⏳ Please wait. ${_currentPosition! - 1} ${_currentPosition! - 1 == 1 ? 'person' : 'people'} ahead.';
    }
  }
}

/// Compact version for smaller spaces
class CompactPositionTracker extends StatelessWidget {
  final String tokenId;
  final String serviceId;

  const CompactPositionTracker({
    Key? key,
    required this.tokenId,
    required this.serviceId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PositionTrackerWidget(
      tokenId: tokenId,
      serviceId: serviceId,
    );
  }
}
