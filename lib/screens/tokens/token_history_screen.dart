import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import '../../models/token.dart';
import '../../models/service.dart';
import 'package:intl/intl.dart';

class TokenHistoryScreen extends StatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  State<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends State<TokenHistoryScreen> {
  List<Token> allTokens = [];
  List<Token> filteredTokens = [];
  bool isLoading = true;
  String selectedFilter = 'all'; // all, completed, rejected, cancelled

  @override
  void initState() {
    super.initState();
    _loadTokenHistory();
  }

  Future<void> _loadTokenHistory() async {
    setState(() => isLoading = true);

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      final response = await SupabaseConfig.client
          .from('tokens')
          .select('''
            *,
            services:service_id (
              id,
              name,
              type,
              estimated_time_minutes
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final tokens = (response as List).map((json) {
        // Parse service data
        final serviceData = json['services'];
        ServiceType? serviceType;
        if (serviceData != null && serviceData['type'] != null) {
          serviceType = ServiceType.values.firstWhere(
            (e) => e.name == serviceData['type'],
            orElse: () => ServiceType.licenseRenewal,
          );
        }

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
          bookedAt: json['booked_at'] != null
              ? DateTime.parse(json['booked_at'])
              : null,
          serviceName: serviceData?['name'],
          serviceType: serviceType,
        );
      }).toList();

      setState(() {
        allTokens = tokens;
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading token history: $e');
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      if (selectedFilter == 'all') {
        filteredTokens = allTokens;
      } else if (selectedFilter == 'completed') {
        filteredTokens = allTokens.where((t) => t.status == TokenStatus.completed).toList();
      } else if (selectedFilter == 'rejected') {
        filteredTokens = allTokens.where((t) => t.status == TokenStatus.rejected).toList();
      } else if (selectedFilter == 'cancelled') {
        filteredTokens = allTokens.where((t) => t.status == TokenStatus.noShow).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token History'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTokenHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', allTokens.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed',
                    'completed',
                    allTokens.where((t) => t.status == TokenStatus.completed).length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Rejected',
                    'rejected',
                    allTokens.where((t) => t.status == TokenStatus.rejected).length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Cancelled',
                    'cancelled',
                    allTokens.where((t) => t.status == TokenStatus.noShow).length,
                  ),
                ],
              ),
            ),
          ),

          // Token List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTokens.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTokenHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTokens.length,
                          itemBuilder: (context, index) {
                            final token = filteredTokens[index];
                            return _buildTokenCard(token);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
          _applyFilter();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildTokenCard(Token token) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Token Number and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Token ${token.displayToken}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: token.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: token.statusColor),
                  ),
                  child: Text(
                    token.statusText,
                    style: TextStyle(
                      color: token.statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Service Name
            Row(
              children: [
                Icon(Icons.room_service, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    token.serviceName ?? 'Unknown Service',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Booked Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Booked: ${DateFormat('MMM dd, yyyy - hh:mm a').format(token.bookedAt ?? token.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            // Completed Date (if completed)
            if (token.completedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Completed: ${DateFormat('MMM dd, yyyy - hh:mm a').format(token.completedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],

            // Processing Time (if completed)
            if (token.startedAt != null && token.completedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Processing Time: ${_calculateDuration(token.startedAt!, token.completedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],

            // Notes (if any)
            if (token.notes != null && token.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        token.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No tokens found';
    String subtitle = 'Your token history will appear here';

    if (selectedFilter == 'completed') {
      message = 'No completed tokens';
      subtitle = 'Tokens you\'ve completed will appear here';
    } else if (selectedFilter == 'rejected') {
      message = 'No rejected tokens';
      subtitle = 'Rejected tokens will appear here';
    } else if (selectedFilter == 'cancelled') {
      message = 'No cancelled tokens';
      subtitle = 'Cancelled tokens will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
