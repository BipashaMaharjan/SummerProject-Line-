import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/queue_status_service.dart';
import '../../config/supabase_config.dart';

/// Public Display Board - Full screen view for TV/Monitor in waiting area
/// Shows currently serving token in HUGE text with next tokens in queue
class PublicDisplayBoardScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;

  const PublicDisplayBoardScreen({
    Key? key,
    required this.serviceId,
    required this.serviceName,
  }) : super(key: key);

  @override
  State<PublicDisplayBoardScreen> createState() => _PublicDisplayBoardScreenState();
}

class _PublicDisplayBoardScreenState extends State<PublicDisplayBoardScreen> {
  final QueueStatusService _queueService = QueueStatusService();
  QueueStatus? _currentStatus;
  List<Map<String, dynamic>> _upcomingTokens = [];
  Timer? _refreshTimer;
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUpcomingTokens();
    
    // Auto-refresh upcoming tokens every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUpcomingTokens();
    });
  }

  @override
  void dispose() {
    // ✅ FIX: Clean up all resources to prevent memory leak
    _refreshTimer?.cancel();
    _queueService.dispose();
    super.dispose();
  }

  Future<void> _loadUpcomingTokens() async {
    try {
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('token_number, created_at')
          .eq('service_id', widget.serviceId)
          .eq('status', 'waiting')
          .order('priority', ascending: false)
          .order('created_at', ascending: true)
          .limit(5);

      if (mounted) {
        setState(() {
          _upcomingTokens = List<Map<String, dynamic>>.from(response);
          _lastUpdate = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error loading upcoming tokens: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<QueueStatus>(
          stream: _queueService.subscribeToQueueUpdates(widget.serviceId),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _currentStatus = snapshot.data!;
            }

            return Column(
              children: [
                // Header with service name and time
                _buildHeader(),
                
                const SizedBox(height: 20),
                
                // Main display - Currently Serving
                Expanded(
                  flex: 3,
                  child: _buildCurrentlyServing(),
                ),
                
                const SizedBox(height: 20),
                
                // Upcoming tokens
                Expanded(
                  flex: 2,
                  child: _buildUpcomingTokens(),
                ),
                
                const SizedBox(height: 20),
                
                // Footer
                _buildFooter(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Service name
          Text(
            widget.serviceName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Current time
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              return Text(
                _formatTime(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 28,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyServing() {
    final hasToken = _currentStatus?.currentTokenNumber != null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasToken 
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.grey.shade800, Colors.grey.shade700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: hasToken ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "Now Serving" label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasToken ? Icons.campaign : Icons.hourglass_empty,
                color: Colors.white,
                size: 60,
              ),
              const SizedBox(width: 20),
              const Text(
                'NOW SERVING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 8,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Token number - HUGE
          Text(
            hasToken ? _currentStatus!.currentTokenNumber! : '---',
            style: TextStyle(
              color: Colors.white,
              fontSize: 180,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          
          // Live indicator
          if (hasToken) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingTokens() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.queue, color: Colors.blue.shade300, size: 32),
              const SizedBox(width: 15),
              Text(
                'UPCOMING TOKENS',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Token list
          Expanded(
            child: _upcomingTokens.isEmpty
                ? Center(
                    child: Text(
                      'No tokens in queue',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 24,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _upcomingTokens.length,
                    itemBuilder: (context, index) {
                      final token = _upcomingTokens[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          children: [
                            // Position indicator
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade800,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 20),
                            
                            // Token number
                            Text(
                              token['token_number'] ?? '---',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Please be ready when your number is called',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 20,
            ),
          ),
          Text(
            'Last updated: ${_formatTime(_lastUpdate)}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
