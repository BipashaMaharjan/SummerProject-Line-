import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/token.dart';

class TokenCard extends StatelessWidget {
  final Token token;
  final VoidCallback? onStartOperation;
  final bool showActionButton;

  const TokenCard({
    super.key,
    required this.token,
    this.onStartOperation,
    this.showActionButton = false,
  });

  Color _getStatusColor(TokenStatus status) {
    switch (status) {
      case TokenStatus.waiting:
        return Colors.orange;
      case TokenStatus.hold:
        return Colors.purple;
      case TokenStatus.processing:
        return Colors.blue;
      case TokenStatus.completed:
        return Colors.green;
      case TokenStatus.rejected:
      case TokenStatus.noShow:
        return Colors.red;
    }
  }

  List<Widget> _buildStatusInfo() {
    final status = token.status;
    final startedAt = token.startedAt;
    final now = DateTime.now();
    
    return [
      const SizedBox(height: 16),
      // Show current status with color coding
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          status.displayName.toUpperCase(),
          style: TextStyle(
            color: _getStatusColor(status),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
      const SizedBox(height: 12),
      
      // Show started time if available
      if (startedAt != null) ...[
        _buildInfoRow(
          'Started at',
          '${DateFormat('hh:mm a').format(startedAt)} (${_formatDuration(now.difference(startedAt))} ago)',
        ),
        const SizedBox(height: 4),
      ],
      
      // Show estimated wait time for processing tokens
      if (status == TokenStatus.processing) ...[
        _buildInfoRow(
          'Estimated wait time',
          'Approx. 10-15 minutes', // TODO: Replace with dynamic calculation
        ),
        const SizedBox(height: 4),
      ]
      // Show position in queue for waiting tokens
      else if (status == TokenStatus.waiting) ...[
        if (token.queuePosition != null) ...[
          _buildInfoRow(
            'Position in queue',
            '${token.queuePosition} ${token.queuePosition == 1 ? 'person' : 'people'} ahead of you',
          ),
          const SizedBox(height: 4),
        ] else ...[
          _buildInfoRow(
            'Status',
            'Waiting for processing to start',
          ),
          const SizedBox(height: 4),
        ]
      ],
      
      // Show current room information
      if (token.currentRoomName != null) ...[
        _buildInfoRow(
          'Current Room',
          '${token.currentRoomName}${token.currentRoomNumber != null ? ' (${token.currentRoomNumber})' : ''}',
        ),
      ],
    ];
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onStartOperation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Start Operation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {
          // TODO: Implement token details navigation
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '#${token.tokenNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  if (token.serviceName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        token.serviceName!,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              ..._buildStatusInfo(),
              if (showActionButton && onStartOperation != null && token.status == TokenStatus.waiting)
                _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }
}
