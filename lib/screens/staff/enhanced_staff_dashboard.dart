import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/token.dart';
import './token_details_screen.dart';
import './staff_statistics_screen.dart';

class EnhancedStaffDashboard extends StatefulWidget {
  const EnhancedStaffDashboard({super.key});

  @override
  State<EnhancedStaffDashboard> createState() => _EnhancedStaffDashboardState();
}

class _EnhancedStaffDashboardState extends State<EnhancedStaffDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialLoaded = false;
  String _searchQuery = '';
  String? _selectedService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _setupRealtimeUpdates();
  }

  void _setupRealtimeUpdates() {
    context.read<TokenProvider>().subscribeToTokenUpdates((data) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refresh() async {
    // Get staff's assigned room from their profile
    final authProvider = context.read<AuthProvider>();
    final assignedRoomId = authProvider.profile?.assignedRoomId;
    
    debugPrint('🔍 Staff Dashboard Refresh:');
    debugPrint('   Staff ID: ${authProvider.user?.id}');
    debugPrint('   Staff Email: ${authProvider.user?.email}');
    debugPrint('   Staff Role: ${authProvider.profile?.role}');
    debugPrint('   Assigned Room ID: $assignedRoomId');
    
    // Fetch tokens filtered by assigned room (only for staff with assigned rooms)
    await context.read<TokenProvider>().getTodaysQueue(
      filterByRoomId: assignedRoomId,
    );
    
    final tokens = context.read<TokenProvider>().allTokens;
    debugPrint('📊 Total tokens loaded: ${tokens.length}');
    debugPrint('📊 Waiting tokens: ${tokens.where((t) => t.status == TokenStatus.waiting).length}');
    
    if (mounted && !_initialLoaded) setState(() => _initialLoaded = true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    context.read<TokenProvider>().unsubscribeFromTokenUpdates();
    super.dispose();
  }

  List<Token> _filterTokens(List<Token> tokens) {
    var filtered = tokens;
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) =>
        t.displayToken.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (t.serviceName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    // Service filter
    if (_selectedService != null) {
      filtered = filtered.where((t) => t.serviceName == _selectedService).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TokenProvider>();
    final tokens = tp.allTokens;

    final waiting = _filterTokens(tokens.where((t) => t.status == TokenStatus.waiting).toList());
    final processing = _filterTokens(tokens.where((t) => t.status == TokenStatus.processing).toList());
    final hold = _filterTokens(tokens.where((t) => t.status == TokenStatus.hold).toList());
    final completed = _filterTokens(tokens.where((t) => t.status == TokenStatus.completed).toList());

    // Get unique services for filter
    final services = tokens.map((t) => t.serviceName).where((s) => s != null).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          // Statistics button
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StaffStatisticsScreen()),
              );
            },
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(160),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stats Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCard(
                        label: 'Waiting',
                        count: waiting.length,
                        color: Colors.orange,
                        icon: Icons.hourglass_empty,
                      ),
                      _StatCard(
                        label: 'Processing',
                        count: processing.length,
                        color: Colors.blue,
                        icon: Icons.play_circle,
                      ),
                      _StatCard(
                        label: 'Hold',
                        count: hold.length,
                        color: Colors.red,
                        icon: Icons.pause_circle,
                      ),
                      _StatCard(
                        label: 'Completed',
                        count: completed.length,
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                    ],
                  ),
                ),
                // Search and Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.filter_list, size: 20),
                        tooltip: 'Filter',
                        onSelected: (value) => setState(() => _selectedService = value == 'all' ? null : value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'all', child: Text('All Services')),
                          ...services.map((s) => PopupMenuItem(value: s, child: Text(s!))),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelStyle: const TextStyle(fontSize: 12),
                  tabs: [
                    Tab(text: 'Wait (${waiting.length})'),
                    Tab(text: 'Process (${processing.length})'),
                    Tab(text: 'Hold (${hold.length})'),
                    Tab(text: 'Done (${completed.length})'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabController,
          children: [
            _TokenList(tokens: waiting, emptyText: 'No waiting tokens', onRefresh: _refresh),
            _TokenList(tokens: processing, emptyText: 'No processing tokens', onRefresh: _refresh),
            _TokenList(tokens: hold, emptyText: 'No tokens on hold', onRefresh: _refresh),
            _TokenList(tokens: completed, emptyText: 'No completed tokens', onRefresh: _refresh),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: waiting.isNotEmpty 
            ? () => _callNext(waiting.first)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No waiting tokens in queue'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
        backgroundColor: waiting.isNotEmpty ? Colors.green : Colors.grey,
        icon: Icon(
          waiting.isNotEmpty ? Icons.phone_forwarded : Icons.phone_disabled,
        ),
        label: Text(waiting.isNotEmpty ? 'Call Next' : 'No Tokens'),
      ),
    );
  }

  Future<void> _callNext(Token token) async {
    // Show dialog with token number
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📢 Call Next Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    'Now Calling',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    token.displayToken,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    token.serviceName ?? 'Service',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start processing this token?',
              style: TextStyle(fontSize: 14),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Start Processing'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Navigate to token details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TokenDetailsScreen(token: token),
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class _TokenList extends StatelessWidget {
  final List<Token> tokens;
  final String emptyText;
  final VoidCallback onRefresh;

  const _TokenList({
    required this.tokens,
    required this.emptyText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(emptyText, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = tokens[i];
        return _TokenCard(token: t, onRefresh: onRefresh);
      },
    );
  }
}

class _TokenCard extends StatelessWidget {
  final Token token;
  final VoidCallback onRefresh;

  const _TokenCard({required this.token, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TokenDetailsScreen(token: token),
            ),
          ).then((_) => onRefresh());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Token Number
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: token.statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      token.displayToken,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: token.statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Service Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          token.serviceName ?? 'Service',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          token.userName ?? 'Customer',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: token.statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      token.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Room Information
              Row(
                children: [
                  Icon(Icons.room, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Current: ${token.currentRoomName ?? "N/A"} (${token.currentRoomNumber ?? ""})',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              if (token.queuePosition != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Position: ${token.queuePosition}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Action Buttons
              _ActionButtons(token: token, onRefresh: onRefresh),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Token token;
  final VoidCallback onRefresh;

  const _ActionButtons({required this.token, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    switch (token.status) {
      case TokenStatus.waiting:
      case TokenStatus.hold:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Processing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _startProcessing(context),
              ),
            ),
          ],
        );
      case TokenStatus.processing:
        // No action buttons in list view - user must open token details
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _startProcessing(BuildContext context) async {
    if (token.currentRoomId == null) {
      _showSnackBar(context, 'Token has no room assigned');
      return;
    }
    
    final success = await context.read<TokenProvider>().startOperation(
      token.id,
      token.currentRoomId!,
    );
    
    if (success) {
      _showSnackBar(context, '✅ Started processing ${token.displayToken}');
      onRefresh();
    } else {
      _showSnackBar(context, '❌ Failed to start processing');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
