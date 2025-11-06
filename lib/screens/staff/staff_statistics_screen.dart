import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';

class StaffStatisticsScreen extends StatefulWidget {
  const StaffStatisticsScreen({super.key});

  @override
  State<StaffStatisticsScreen> createState() => _StaffStatisticsScreenState();
}

class _StaffStatisticsScreenState extends State<StaffStatisticsScreen> {
  bool _loading = true;
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Get today's tokens
      final tokensResponse = await SupabaseConfig.client
          .from('tokens')
          .select()
          .gte('booked_at', startOfDay.toIso8601String());

      final tokens = tokensResponse as List;

      setState(() {
        _stats = {
          'total': tokens.length,
          'waiting': tokens.where((t) => t['status'] == 'waiting').length,
          'processing': tokens.where((t) => t['status'] == 'processing').length,
          'completed': tokens.where((t) => t['status'] == 'completed').length,
          'rejected': tokens.where((t) => t['status'] == 'rejected').length,
          'hold': tokens.where((t) => t['status'] == 'hold').length,
        };
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadStatistics();
            },
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
                  const Text(
                    'Today\'s Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Total Tokens Card
                  _StatCard(
                    title: 'Total Tokens',
                    value: _stats['total']?.toString() ?? '0',
                    icon: Icons.confirmation_number,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  
                  // Status Breakdown
                  Row(
                    children: [
                      Expanded(
                        child: _SmallStatCard(
                          title: 'Waiting',
                          value: _stats['waiting']?.toString() ?? '0',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallStatCard(
                          title: 'Processing',
                          value: _stats['processing']?.toString() ?? '0',
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallStatCard(
                          title: 'Completed',
                          value: _stats['completed']?.toString() ?? '0',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallStatCard(
                          title: 'Rejected',
                          value: _stats['rejected']?.toString() ?? '0',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Performance Metrics
                  const Text(
                    'Performance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  _PerformanceCard(
                    title: 'Completion Rate',
                    value: _calculateCompletionRate(),
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  
                  _PerformanceCard(
                    title: 'Average Wait Time',
                    value: '15 min', // TODO: Calculate from actual data
                    icon: Icons.access_time,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
    );
  }

  String _calculateCompletionRate() {
    final total = _stats['total'] ?? 0;
    final completed = _stats['completed'] ?? 0;
    if (total == 0) return '0%';
    return '${((completed / total) * 100).toStringAsFixed(1)}%';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 32,
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
}

class _SmallStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SmallStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _PerformanceCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
