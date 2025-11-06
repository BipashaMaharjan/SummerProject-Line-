// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/token_provider.dart';
// import '../../models/token.dart';
// import '../../config/supabase_config.dart';

// class StaffDashboardScreen extends StatefulWidget {
//   const StaffDashboardScreen({super.key});

//   @override
//   State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
// }

// class _StaffDashboardScreenState extends State<StaffDashboardScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   bool _initialLoaded = false;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     // Load on first frame
//     WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
//     // Setup real-time updates
//     _setupRealtimeUpdates();
//   }

//   void _setupRealtimeUpdates() {
//     context.read<TokenProvider>().subscribeToTokenUpdates((data) {
//       if (mounted) {
//         // Tokens will auto-refresh via provider
//         setState(() {});
//       }
//     });
//   }

//   Future<void> _refresh() async {
//     await context.read<TokenProvider>().getTodaysQueue();
//     if (mounted && !_initialLoaded) setState(() => _initialLoaded = true);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     context.read<TokenProvider>().unsubscribeFromTokenUpdates();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tp = context.watch<TokenProvider>();
//     final tokens = tp.allTokens; // Use allTokens for staff dashboard

//     final waiting = tokens.where((t) => t.status == TokenStatus.waiting).toList();
//     final hold = tokens.where((t) => t.status == TokenStatus.hold).toList();
//     final processing = tokens.where((t) => t.status == TokenStatus.processing).toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Staff Dashboard'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: 'Waiting'),
//             Tab(text: 'Hold'),
//             Tab(text: 'Processing'),
//           ],
//         ),
//       ),
//       body: RefreshIndicator(
//         onRefresh: _refresh,
//         child: TabBarView(
//           controller: _tabController,
//           children: [
//             _TokenList(
//               tokens: waiting, 
//               emptyText: 'No waiting tokens', 
//               onStart: _onStart, 
//               onComplete: _onComplete,
//               onTransfer: _onTransferToNextRoom,
//               onReject: _onReject,
//             ),
//             _TokenList(
//               tokens: hold, 
//               emptyText: 'No tokens on hold', 
//               onStart: _onStart, 
//               onComplete: _onComplete,
//               onTransfer: _onTransferToNextRoom,
//               onReject: _onReject,
//             ),
//             _TokenList(
//               tokens: processing, 
//               emptyText: 'No processing tokens', 
//               onStart: _onStart, 
//               onComplete: _onComplete,
//               onTransfer: _onTransferToNextRoom,
//               onReject: _onReject,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _refresh,
//         child: const Icon(Icons.refresh),
//       ),
//     );
//   }

//   Future<void> _onStart(Token token) async {
//     if (token.currentRoomId == null) {
//       _snack('Token has no room assigned');
//       return;
//     }
//     final ok = await context.read<TokenProvider>().startOperation(token.id, token.currentRoomId!);
//     if (ok) {
//       _snack('Started ${token.displayToken}');
//       await _refresh();
//     } else {
//       _snack('Failed to start');
//     }
//   }

//   Future<void> _onTransferToNextRoom(Token token) async {
//     try {
//       // Get the service workflow to find next room
//       final workflowResponse = await SupabaseConfig.client
//           .from('service_workflow')
//           .select('*')
//           .eq('service_id', token.serviceId)
//           .order('sequence_order');

//       if ((workflowResponse as List).isEmpty) {
//         _snack('No workflow found for this service');
//         return;
//       }

//       // Find current room in workflow
//       final workflow = workflowResponse;
//       int currentIndex = workflow.indexWhere(
//         (step) => step['room_id'] == token.currentRoomId
//       );

//       if (currentIndex == -1) {
//         _snack('Current room not found in workflow');
//         return;
//       }

//       print('DEBUG: Current room index: $currentIndex, Workflow length: ${workflow.length}');
//       print('DEBUG: Token current room: ${token.currentRoomId}');
//       print('DEBUG: Workflow rooms: ${workflow.map((w) => w['room_id']).toList()}');
      
//       // Check if there's a next room
//       if (currentIndex >= workflow.length - 1) {
//         print('DEBUG: Last room detected - completing token');
//         // Last room - complete the token
//         await _onComplete(token);
//         return;
//       }

//       // Move to next room
//       final nextStep = workflow[currentIndex + 1];
//       final nextRoomId = nextStep['room_id'];
//       final nextSequence = nextStep['sequence_order'];

//       // Get room details separately
//       final roomResponse = await SupabaseConfig.client
//           .from('rooms')
//           .select('name, room_number')
//           .eq('id', nextRoomId)
//           .single();

//       // Update token to next room
//       await SupabaseConfig.client
//           .from('tokens')
//           .update({
//             'current_room_id': nextRoomId,
//             'current_sequence': nextSequence,
//             'status': 'waiting', // Reset to waiting for next room
//           })
//           .eq('id', token.id);

//       // Add history entry
//       await SupabaseConfig.client
//           .from('token_history')
//           .insert({
//             'token_id': token.id,
//             'from_room_id': token.currentRoomId,
//             'to_room_id': nextRoomId,
//             'action': 'transferred',
//             'notes': 'Transferred to ${roomResponse['name']} (${roomResponse['room_number']})',
//             'performed_by': SupabaseConfig.client.auth.currentUser?.id,
//           });

//       _snack('Transferred ${token.displayToken} to ${roomResponse['name']}');
//       await _refresh();
//     } catch (e) {
//       _snack('Failed to transfer: $e');
//     }
//   }

//   Future<void> _onComplete(Token token) async {
//     try {
//       if (token.currentRoomId == null) {
//         _snack('Token has no room assigned');
//         return;
//       }
//       // Mark completed directly and add history
//       await SupabaseConfig.client
//           .from('tokens')
//           .update({
//             'status': 'completed',
//             'completed_at': DateTime.now().toIso8601String(),
//           })
//           .eq('id', token.id);

//       await SupabaseConfig.client.from('token_history').insert({
//         'token_id': token.id,
//         'room_id': token.currentRoomId,
//         'status': 'completed',
//         'action': 'completed',
//         'notes': 'Completed by staff',
//       });

//       _snack('Completed ${token.displayToken}');
//       await _refresh();
//     } catch (e) {
//       _snack('Failed to complete: $e');
//     }
//   }

//   Future<void> _onReject(Token token) async {
//     // Show dialog to get rejection reason
//     final reason = await showDialog<String>(
//       context: context,
//       builder: (context) => _RejectDialog(),
//     );

//     if (reason != null && reason.isNotEmpty) {
//       final ok = await context.read<TokenProvider>().rejectToken(token.id, reason);
//       if (ok) {
//         _snack('Rejected ${token.displayToken}. Next token advanced.');
//         await _refresh();
//       } else {
//         _snack('Failed to reject token');
//       }
//     }
//   }

//   void _snack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
// }

// class _TokenList extends StatelessWidget {
//   final List<Token> tokens;
//   final String emptyText;
//   final Future<void> Function(Token) onStart;
//   final Future<void> Function(Token) onComplete;
//   final Future<void> Function(Token) onTransfer;
//   final Future<void> Function(Token) onReject;

//   const _TokenList({
//     required this.tokens,
//     required this.emptyText,
//     required this.onStart,
//     required this.onComplete,
//     required this.onTransfer,
//     required this.onReject,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (tokens.isEmpty) {
//       return ListView(
//         children: [
//           const SizedBox(height: 32),
//           Center(child: Text(emptyText)),
//         ],
//       );
//     }

//     return ListView.separated(
//       padding: const EdgeInsets.all(12),
//       itemCount: tokens.length,
//       separatorBuilder: (_, __) => const SizedBox(height: 8),
//       itemBuilder: (ctx, i) {
//         final t = tokens[i];
//         return Card(
//           child: ListTile(
//             leading: CircleAvatar(
//               backgroundColor: t.statusColor.withOpacity(0.15),
//               child: Text(t.displayToken, style: const TextStyle(fontWeight: FontWeight.bold)),
//             ),
//             title: Text(t.serviceName ?? 'Service'),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (t.currentRoomName != null)
//                   Text('Room: ${t.currentRoomName} (${t.currentRoomNumber ?? ''})'),
//                 Text('Status: ${t.statusText}'),
//                 if (t.queuePosition != null)
//                   Text('Position: ${t.queuePosition}'),
//               ],
//             ),
//             trailing: _Actions(
//               token: t, 
//               onStart: onStart, 
//               onComplete: onComplete,
//               onTransfer: onTransfer,
//               onReject: onReject,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class _Actions extends StatelessWidget {
//   final Token token;
//   final Future<void> Function(Token) onStart;
//   final Future<void> Function(Token) onComplete;
//   final Future<void> Function(Token) onTransfer;
//   final Future<void> Function(Token) onReject;
//   const _Actions({
//     required this.token, 
//     required this.onStart, 
//     required this.onComplete,
//     required this.onTransfer,
//     required this.onReject,
//   });

//   @override
//   Widget build(BuildContext context) {
//     switch (token.status) {
//       case TokenStatus.waiting:
//       case TokenStatus.hold:
//         return IconButton(
//           icon: const Icon(Icons.play_circle_fill),
//           tooltip: 'Start',
//           onPressed: () => onStart(token),
//           color: Colors.blue,
//         );
//       case TokenStatus.processing:
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             IconButton(
//               icon: const Icon(Icons.cancel),
//               tooltip: 'Reject',
//               onPressed: () => onReject(token),
//               color: Colors.red,
//             ),
//             IconButton(
//               icon: const Icon(Icons.arrow_forward),
//               tooltip: 'Next Room',
//               onPressed: () => onTransfer(token),
//               color: Colors.orange,
//             ),
//             IconButton(
//               icon: const Icon(Icons.check_circle),
//               tooltip: 'Complete',
//               onPressed: () => onComplete(token),
//               color: Colors.green,
//             ),
//           ],
//         );
//       case TokenStatus.completed:
//       case TokenStatus.rejected:
//       case TokenStatus.noShow:
//         return const SizedBox.shrink();
//     }
//   }
// }

// class _RejectDialog extends StatefulWidget {
//   @override
//   State<_RejectDialog> createState() => _RejectDialogState();
// }

// class _RejectDialogState extends State<_RejectDialog> {
//   final _controller = TextEditingController();
//   String? _selectedReason;

//   final List<String> _commonReasons = [
//     'Trial Failure',
//     'Biometric Failure',
//     'Incomplete Documents',
//     'Payment Issue',
//     'Customer Request',
//     'Other',
//   ];

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Reject Token'),
//       content: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Select rejection reason:'),
//             const SizedBox(height: 12),
//             ..._commonReasons.map((reason) => RadioListTile<String>(
//               title: Text(reason),
//               value: reason,
//               groupValue: _selectedReason,
//               onChanged: (value) {
//                 setState(() => _selectedReason = value);
//               },
//               dense: true,
//               contentPadding: EdgeInsets.zero,
//             )),
//             if (_selectedReason == 'Other') ...[
//               const SizedBox(height: 12),
//               TextField(
//                 controller: _controller,
//                 decoration: const InputDecoration(
//                   labelText: 'Specify reason',
//                   border: OutlineInputBorder(),
//                 ),
//                 maxLines: 2,
//               ),
//             ],
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             final reason = _selectedReason == 'Other'
//                 ? _controller.text.trim()
//                 : _selectedReason;
//             if (reason != null && reason.isNotEmpty) {
//               Navigator.pop(context, reason);
//             }
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.red,
//             foregroundColor: Colors.white,
//           ),
//           child: const Text('Reject'),
//         ),
//       ],
//     );
//   }
// }
