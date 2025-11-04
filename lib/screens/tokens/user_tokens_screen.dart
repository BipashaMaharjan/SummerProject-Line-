import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../widgets/token_card.dart';
import '../../models/token.dart';

class UserTokensScreen extends StatefulWidget {
  const UserTokensScreen({super.key});

  @override
  State<UserTokensScreen> createState() => _UserTokensScreenState();
}

class _UserTokensScreenState extends State<UserTokensScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<TokenStatus, List<Token>> _tokensByStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load user tokens when the screen is first displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserTokens();
      _setupRealtimeUpdates();
    });
  }

  void _setupRealtimeUpdates() {
    context.read<TokenProvider>().subscribeToTokenUpdates((data) {
      if (mounted) {
        _loadUserTokens();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    context.read<TokenProvider>().unsubscribeFromTokenUpdates();
    super.dispose();
  }

  Future<void> _loadUserTokens() async {
    if (mounted) setState(() => _isLoading = true);
    
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    await tokenProvider.loadUserTokens();
    
    if (mounted) {
      // Group tokens by status
      _tokensByStatus.clear();
      for (final token in tokenProvider.userTokens) {
        _tokensByStatus.putIfAbsent(token.status, () => []).add(token);
      }
      
      // Sort tokens within each status group
      _tokensByStatus.forEach((status, tokens) {
        tokens.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tokens'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserTokens,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserTokens,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Tab - Show in-progress and waiting tokens
                  _buildTokenList([
                    ...?_tokensByStatus[TokenStatus.processing],
                    ...?_tokensByStatus[TokenStatus.waiting],
                  ]),
                  // Upcoming Tab - Show hold tokens
                  _buildTokenList(_tokensByStatus[TokenStatus.hold]),
                  // History Tab - Show completed, rejected, and no-show tokens
                  _buildTokenList([
                    ...?_tokensByStatus[TokenStatus.completed],
                    ...?_tokensByStatus[TokenStatus.rejected],
                    ...?_tokensByStatus[TokenStatus.noShow],
                  ]),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTokenList(List<Token>? tokens) {
    if (tokens == null || tokens.isEmpty) {
      return const Center(
        child: Text('No tokens found'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: tokens.length,
      itemBuilder: (context, index) {
        final token = tokens[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              TokenCard(token: token),
              if (token.status == TokenStatus.waiting || token.status == TokenStatus.processing)
                _buildTokenActions(token),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTokenActions(Token token) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (token.status == TokenStatus.waiting) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _postponeToken(token),
                icon: const Icon(Icons.schedule),
                label: const Text('Postpone'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cancelToken(token),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postponeToken(Token token) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Postpone Token'),
        content: const Text('Your token will be moved to the end of the queue. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'User requested postponement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Postpone'),
          ),
        ],
      ),
    );

    if (reason != null) {
      final success = await context.read<TokenProvider>().postponeToken(token.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Token postponed successfully' : 'Failed to postpone token'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) _loadUserTokens();
      }
    }
  }

  Future<void> _cancelToken(Token token) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Token'),
        content: const Text('Are you sure you want to cancel this token? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await context.read<TokenProvider>().cancelToken(token.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Token cancelled successfully' : 'Failed to cancel token'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) _loadUserTokens();
      }
    }
  }
}
