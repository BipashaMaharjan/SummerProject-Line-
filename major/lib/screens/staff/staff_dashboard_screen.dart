import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../models/token.dart';
import '../../config/supabase_config.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context.read<TokenProvider>().getTodaysQueue();
    if (mounted && !_initialLoaded) setState(() => _initialLoaded = true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TokenProvider>();
    final tokens = tp.userTokens;

    final waiting = tokens.where((t) => t.status == TokenStatus.waiting).toList();
    final hold = tokens.where((t) => t.status == TokenStatus.hold).toList();
    final processing = tokens.where((t) => t.status == TokenStatus.processing).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Waiting'),
            Tab(text: 'Hold'),
            Tab(text: 'Processing'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabController,
          children: [
            _TokenList(tokens: waiting, emptyText: 'No waiting tokens', onStart: _onStart, onComplete: _onComplete),
            _TokenList(tokens: hold, emptyText: 'No tokens on hold', onStart: _onStart, onComplete: _onComplete),
            _TokenList(tokens: processing, emptyText: 'No processing tokens', onStart: _onStart, onComplete: _onComplete),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Future<void> _onStart(Token token) async {
    if (token.currentRoomId == null) {
      _snack('Token has no room assigned');
      return;
    }
    final ok = await context.read<TokenProvider>().startOperation(token.id, token.currentRoomId!);
    if (ok) {
      _snack('Started ${token.displayToken}');
      await _refresh();
    } else {
      _snack('Failed to start');
    }
  }

  Future<void> _onComplete(Token token) async {
    try {
      if (token.currentRoomId == null) {
        _snack('Token has no room assigned');
        return;
      }
      // Mark completed directly and add history
      await SupabaseConfig.client
          .from('tokens')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', token.id);

      await SupabaseConfig.client.from('token_history').insert({
        'token_id': token.id,
        'room_id': token.currentRoomId,
        'status': 'completed',
        'action': 'completed',
        'notes': 'Completed by staff',
      });

      _snack('Completed ${token.displayToken}');
      await _refresh();
    } catch (e) {
      _snack('Failed to complete: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _TokenList extends StatelessWidget {
  final List<Token> tokens;
  final String emptyText;
  final Future<void> Function(Token) onStart;
  final Future<void> Function(Token) onComplete;

  const _TokenList({
    required this.tokens,
    required this.emptyText,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 32),
          Center(child: Text(emptyText)),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = tokens[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: t.statusColor.withOpacity(0.15),
              child: Text(t.displayToken, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(t.serviceName ?? 'Service'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.currentRoomName != null)
                  Text('Room: ${t.currentRoomName} (${t.currentRoomNumber ?? ''})'),
                Text('Status: ${t.statusText}'),
                if (t.queuePosition != null)
                  Text('Position: ${t.queuePosition}'),
              ],
            ),
            trailing: _Actions(token: t, onStart: onStart, onComplete: onComplete),
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  final Token token;
  final Future<void> Function(Token) onStart;
  final Future<void> Function(Token) onComplete;
  const _Actions({required this.token, required this.onStart, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    switch (token.status) {
      case TokenStatus.waiting:
      case TokenStatus.hold:
        return IconButton(
          icon: const Icon(Icons.play_circle_fill),
          tooltip: 'Start',
          onPressed: () => onStart(token),
          color: Colors.blue,
        );
      case TokenStatus.processing:
        return IconButton(
          icon: const Icon(Icons.check_circle),
          tooltip: 'Complete',
          onPressed: () => onComplete(token),
          color: Colors.green,
        );
      case TokenStatus.completed:
      case TokenStatus.rejected:
      case TokenStatus.noShow:
        return const SizedBox.shrink();
    }
  }
}
