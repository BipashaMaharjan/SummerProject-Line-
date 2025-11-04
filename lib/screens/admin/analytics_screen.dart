import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import '../../models/token.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;
  Map<String, dynamic> analytics = {};
  String selectedPeriod = 'today'; // today, week, month, all

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (selectedPeriod) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2020, 1, 1); // All time
      }

      // Fetch tokens for the period
      final tokensResponse = await SupabaseConfig.client
          .from('tokens')
          .select('*, services:service_id(name, type)')
          .gte('created_at', startDate.toIso8601String());

      final tokens = (tokensResponse as List).map((json) {
        return Token(
          id: json['id'],
          tokenNumber: json['token_number']?.toString() ?? '',
          userId: json['user_id'],
          serviceId: json['service_id'],
          status: TokenStatus.values.firstWhere(
            (e) => e.name == json['status'],
            orElse: () => TokenStatus.waiting,
          ),
          currentRoomId: json['current_room_id'],
          currentSequence: json['current_sequence'] ?? 1,
          priority: json['priority'] ?? 0,
          notes: json['notes'],
          createdAt: DateTime.parse(json['created_at']),
          updatedAt: DateTime.parse(json['updated_at']),
          completedAt: json['completed_at'] != null
              ? DateTime.parse(json['completed_at'])
              : null,
          startedAt: json['started_at'] != null
              ? DateTime.parse(json['started_at'])
              : null,
          serviceName: json['services']?['name'],
        );
      }).toList();

      // Calculate analytics
      final totalTokens = tokens.length;
      final completedTokens =
          tokens.where((t) => t.status == TokenStatus.completed).length;
      final processingTokens =
          tokens.where((t) => t.status == TokenStatus.processing).length;
      final waitingTokens =
          tokens.where((t) => t.status == TokenStatus.waiting).length;
      final rejectedTokens =
          tokens.where((t) => t.status == TokenStatus.rejected).length;

      // Calculate average processing time
      final completedWithTime = tokens.where((t) =>
          t.status == TokenStatus.completed &&
          t.startedAt != null &&
          t.completedAt != null);

      double avgProcessingTime = 0;
      if (completedWithTime.isNotEmpty) {
        final totalMinutes = completedWithTime.fold<int>(
          0,
          (sum, token) => sum +
              token.completedAt!.difference(token.startedAt!).inMinutes,
        );
        avgProcessingTime = totalMinutes / completedWithTime.length;
      }

      // Group by service
      final serviceStats = <String, int>{};
      for (var token in tokens) {
        final serviceName = token.serviceName ?? 'Unknown';
        serviceStats[serviceName] = (serviceStats[serviceName] ?? 0) + 1;
      }

      // Group by status
      final statusStats = {
        'Completed': completedTokens,
        'Processing': processingTokens,
        'Waiting': waitingTokens,
        'Rejected': rejectedTokens,
      };

      setState(() {
        analytics = {
          'totalTokens': totalTokens,
          'completedTokens': completedTokens,
          'processingTokens': processingTokens,
          'waitingTokens': waitingTokens,
          'rejectedTokens': rejectedTokens,
          'avgProcessingTime': avgProcessingTime,
          'serviceStats': serviceStats,
          'statusStats': statusStats,
          'completionRate': totalTokens > 0
              ? (completedTokens / totalTokens * 100).toStringAsFixed(1)
              : '0',
        };
        isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),

                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),

                    // Status Distribution
                    _buildSectionTitle('Status Distribution'),
                    const SizedBox(height: 12),
                    _buildStatusDistribution(),
                    const SizedBox(height: 24),

                    // Service Statistics
                    _buildSectionTitle('Service Statistics'),
                    const SizedBox(height: 12),
                    _buildServiceStats(),
                    const SizedBox(height: 24),

                    // Performance Metrics
                    _buildSectionTitle('Performance Metrics'),
                    const SizedBox(height: 12),
                    _buildPerformanceMetrics(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Period:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPeriodChip('Today', 'today'),
                    const SizedBox(width: 8),
                    _buildPeriodChip('Last 7 Days', 'week'),
                    const SizedBox(width: 8),
                    _buildPeriodChip('This Month', 'month'),
                    const SizedBox(width: 8),
                    _buildPeriodChip('All Time', 'all'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedPeriod = value;
          _loadAnalytics();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Tokens',
          analytics['totalTokens']?.toString() ?? '0',
          Icons.confirmation_number,
          Colors.blue,
        ),
        _buildStatCard(
          'Completed',
          analytics['completedTokens']?.toString() ?? '0',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Processing',
          analytics['processingTokens']?.toString() ?? '0',
          Icons.pending,
          Colors.orange,
        ),
        _buildStatCard(
          'Waiting',
          analytics['waitingTokens']?.toString() ?? '0',
          Icons.hourglass_empty,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatusDistribution() {
    final statusStats =
        analytics['statusStats'] as Map<String, int>? ?? {};
    
    if (statusStats.isEmpty) {
      return _buildEmptyState('No status data available');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: statusStats.entries.map((entry) {
            final total = analytics['totalTokens'] as int? ?? 1;
            final percentage = (entry.value / total * 100).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${entry.value} ($percentage%)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value / total,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatusColor(entry.key),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildServiceStats() {
    final serviceStats =
        analytics['serviceStats'] as Map<String, int>? ?? {};
    
    if (serviceStats.isEmpty) {
      return _buildEmptyState('No service data available');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: serviceStats.entries.map((entry) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.room_service, color: Colors.blue.shade600),
              ),
              title: Text(entry.key),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.value.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final avgTime = analytics['avgProcessingTime'] as double? ?? 0;
    final completionRate = analytics['completionRate'] as String? ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              'Average Processing Time',
              avgTime > 0 ? '${avgTime.toStringAsFixed(1)} minutes' : 'N/A',
              Icons.timer,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              'Completion Rate',
              '$completionRate%',
              Icons.trending_up,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              'Total Rejected',
              analytics['rejectedTokens']?.toString() ?? '0',
              Icons.cancel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Processing':
        return Colors.blue;
      case 'Waiting':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
