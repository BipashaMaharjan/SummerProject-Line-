import 'package:flutter/material.dart';
import '../utils/exceptions.dart';
import '../utils/error_handler.dart';

/// Reusable error state widget with retry functionality
class ErrorStateWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customMessage;
  final bool showDetails;

  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final appException = error is AppException
        ? error as AppException
        : ErrorHandler.handleError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Icon(
              _getErrorIcon(appException),
              size: 64,
              color: _getErrorColor(appException),
            ),
            const SizedBox(height: 24),

            // Error title
            Text(
              _getErrorTitle(appException),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Error message
            Text(
              customMessage ?? appException.getUserMessage(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),

            // Show technical details in debug mode
            if (showDetails && appException.message.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Details: ${appException.message}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.grey[700],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon(AppException exception) {
    if (exception is NetworkException) return Icons.wifi_off;
    if (exception is AuthException) return Icons.lock_outline;
    if (exception is PermissionException) return Icons.block;
    if (exception is NotFoundException) return Icons.search_off;
    if (exception is RateLimitException) return Icons.timer_off;
    if (exception is TimeoutException) return Icons.access_time;
    return Icons.error_outline;
  }

  Color _getErrorColor(AppException exception) {
    if (exception is NetworkException) return Colors.orange;
    if (exception is AuthException) return Colors.red;
    if (exception is PermissionException) return Colors.red[700]!;
    if (exception is RateLimitException) return Colors.amber;
    return Colors.red;
  }

  String _getErrorTitle(AppException exception) {
    if (exception is NetworkException) return 'Connection Error';
    if (exception is AuthException) return 'Authentication Required';
    if (exception is PermissionException) return 'Access Denied';
    if (exception is NotFoundException) return 'Not Found';
    if (exception is RateLimitException) return 'Too Many Attempts';
    if (exception is TimeoutException) return 'Request Timeout';
    if (exception is ServerException) return 'Server Error';
    return 'Something Went Wrong';
  }
}

/// Compact error message widget (for inline errors)
class ErrorMessageWidget extends StatelessWidget {
  final dynamic error;
  final String? customMessage;

  const ErrorMessageWidget({
    super.key,
    required this.error,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ?? ErrorHandler.getUserMessage(error);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red[900],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state with error fallback
class LoadingOrErrorWidget extends StatelessWidget {
  final bool isLoading;
  final dynamic error;
  final VoidCallback? onRetry;
  final Widget child;
  final String? loadingMessage;

  const LoadingOrErrorWidget({
    super.key,
    required this.isLoading,
    this.error,
    this.onRetry,
    required this.child,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ErrorStateWidget(
        error: error!,
        onRetry: onRetry,
      );
    }

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (loadingMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                loadingMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      );
    }

    return child;
  }
}
