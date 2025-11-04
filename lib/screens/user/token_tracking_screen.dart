import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/token.dart';
import '../../widgets/queue_estimation_widget.dart';
import '../../providers/token_provider.dart';

/// Screen to display real-time token tracking with queue estimation
class TokenTrackingScreen extends StatelessWidget {
  final Token token;
  
  const TokenTrackingScreen({
    super.key,
    required this.token,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Token'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Token Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Token: ${token.displayToken}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildStatusBadge(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      token.serviceName ?? 'Service',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Queue Estimation Widget (NEW!)
            QueueEstimationWidget(token: token),
            
            const SizedBox(height: 16),
            
            // Status Card
            Card(
              elevation: 2,
              color: token.status.statusColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      size: 32,
                      color: token.status.statusColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            token.statusText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusMessage(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Details Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Token Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Token Number', token.tokenNumber),
                    _buildDetailRow('Status', token.statusText),
                    if (token.serviceName != null)
                      _buildDetailRow('Service', token.serviceName!),
                    if (token.currentRoomName != null)
                      _buildDetailRow('Current Room', token.currentRoomName!),
                    _buildDetailRow(
                      'Booked At',
                      '${token.bookedAt?.day ?? token.createdAt.day}/${token.bookedAt?.month ?? token.createdAt.month}/${token.bookedAt?.year ?? token.createdAt.year} ${token.bookedAt?.hour ?? token.createdAt.hour}:${(token.bookedAt?.minute ?? token.createdAt.minute).toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'What to Expect',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(Icons.notifications_active, 'You\'ll receive notifications when your token status changes'),
                    const SizedBox(height: 8),
                    _buildInfoItem(Icons.update, 'This page updates in real-time - no need to refresh'),
                    const SizedBox(height: 8),
                    _buildInfoItem(Icons.room_service, 'Please be ready when your token is called'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: token.status.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: token.status.statusColor, width: 1),
      ),
      child: Text(
        token.statusText.toUpperCase(),
        style: TextStyle(
          color: token.status.statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  IconData _getStatusIcon() {
    switch (token.status) {
      case TokenStatus.waiting:
        return Icons.hourglass_empty;
      case TokenStatus.hold:
        return Icons.pause_circle_outline;
      case TokenStatus.processing:
        return Icons.play_circle_outline;
      case TokenStatus.completed:
        return Icons.check_circle_outline;
      case TokenStatus.rejected:
        return Icons.cancel_outlined;
      case TokenStatus.noShow:
        return Icons.person_off_outlined;
    }
  }
  
  String _getStatusMessage() {
    switch (token.status) {
      case TokenStatus.waiting:
        return 'You are in the queue. Please wait for your turn.';
      case TokenStatus.hold:
        return 'Your token is on hold. Please wait for further instructions.';
      case TokenStatus.processing:
        if (token.currentRoomName != null) {
          return 'Being served in ${token.currentRoomName}';
        }
        return 'Your token is being processed';
      case TokenStatus.completed:
        return 'Service completed successfully';
      case TokenStatus.rejected:
        return 'Token was rejected. Please contact staff.';
      case TokenStatus.noShow:
        return 'Token marked as no-show';
    }
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'What to Expect',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildExpectationItem(
              icon: Icons.notifications_active,
              text: 'You\'ll receive notifications when your token status changes',
            ),
            const SizedBox(height: 8),
            _buildExpectationItem(
              icon: Icons.update,
              text: 'This page updates in real-time - no need to refresh',
            ),
            const SizedBox(height: 8),
            _buildExpectationItem(
              icon: Icons.room_service,
              text: 'Please be ready when your token is called',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpectationItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (token.status == TokenStatus.waiting) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelToken(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Token'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _shareToken(context),
              icon: const Icon(Icons.share),
              label: const Text('Share Token Details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showTrackingInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Real-Time Tracking'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your token is being tracked in real-time using our live system.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Status Updates:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Waiting: You\'re in the queue', style: TextStyle(fontSize: 13)),
            Text('• Processing: Being served now', style: TextStyle(fontSize: 13)),
            Text('• Completed: Service finished', style: TextStyle(fontSize: 13)),
            SizedBox(height: 12),
            Text(
              'The green "Live" indicator shows that you\'re receiving real-time updates.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  void _cancelToken(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Token'),
        content: const Text(
          'Are you sure you want to cancel this token? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              try {
                final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
                await tokenProvider.cancelToken(token.id);
                
                if (context.mounted) {
                  Navigator.pop(context); // Go back to previous screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Token cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel token: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _shareToken(BuildContext context) {
    final tokenDetails = '''
Token Number: ${token.displayToken}
Service: ${token.serviceName ?? 'N/A'}
Status: ${token.statusText}
Booked At: ${token.bookedAt ?? token.createdAt}
    ''';
    
    // TODO: Implement actual sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Token details:\n$tokenDetails'),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
