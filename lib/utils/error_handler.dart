import 'dart:async';
import 'package:flutter/foundation.dart';
import 'exceptions.dart';

/// Centralized error handler with retry logic and user-friendly messages
class ErrorHandler {
  /// Convert generic errors to AppException
  static AppException handleError(dynamic error, [StackTrace? stackTrace]) {
    debugPrint('ErrorHandler: Handling error: $error');

    // Already an AppException
    if (error is AppException) {
      return error;
    }

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return NetworkException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('jwt') ||
        errorString.contains('token') ||
        errorString.contains('unauthorized') ||
        errorString.contains('invalid login')) {
      return AuthException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Rate limiting
    if (errorString.contains('rate limit') || errorString.contains('too many')) {
      return RateLimitException(
        retryAfter: const Duration(minutes: 5),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('forbidden') ||
        errorString.contains('access denied')) {
      return PermissionException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Not found errors
    if (errorString.contains('not found') || errorString.contains('404')) {
      return NotFoundException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('server error')) {
      return ServerException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Timeout errors
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return TimeoutException(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Database/Supabase errors
    if (errorString.contains('postgres') ||
        errorString.contains('supabase') ||
        errorString.contains('foreign key') ||
        errorString.contains('constraint')) {
      return DatabaseException(
        message: 'Database error: ${error.toString()}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default to unknown exception
    return UnknownException(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Execute a function with automatic error handling and retry logic
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    bool exponentialBackoff = true,
    List<Type> retryOn = const [NetworkException, TimeoutException],
  }) async {
    int attempt = 0;
    Duration currentDelay = retryDelay;

    while (true) {
      try {
        attempt++;
        debugPrint('ErrorHandler: Attempt $attempt of ${maxRetries + 1}');
        return await operation();
      } catch (error, stackTrace) {
        final appException = handleError(error, stackTrace);

        // Check if we should retry
        final shouldRetry = attempt <= maxRetries &&
            retryOn.any((type) => appException.runtimeType == type);

        if (!shouldRetry) {
          debugPrint('ErrorHandler: Max retries reached or non-retryable error');
          rethrow;
        }

        debugPrint(
          'ErrorHandler: Retrying after ${currentDelay.inSeconds}s (attempt $attempt)',
        );

        // Wait before retry
        await Future.delayed(currentDelay);

        // Exponential backoff
        if (exponentialBackoff) {
          currentDelay *= 2;
        }
      }
    }
  }

  /// Execute operation with timeout
  static Future<T> executeWithTimeout<T>({
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException catch (e, stackTrace) {
      throw TimeoutException(
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log error for debugging/analytics
  static void logError(AppException exception) {
    debugPrint('=== ERROR LOG ===');
    debugPrint('Type: ${exception.runtimeType}');
    debugPrint('Message: ${exception.message}');
    debugPrint('User Message: ${exception.getUserMessage()}');
    if (exception.originalError != null) {
      debugPrint('Original Error: ${exception.originalError}');
    }
    if (exception.stackTrace != null) {
      debugPrint('Stack Trace: ${exception.stackTrace}');
    }
    debugPrint('================');

    // TODO: Send to analytics/crash reporting service
    // Example: FirebaseCrashlytics.instance.recordError(exception, stackTrace);
  }

  /// Get user-friendly error message
  static String getUserMessage(dynamic error) {
    if (error is AppException) {
      return error.getUserMessage();
    }
    return handleError(error).getUserMessage();
  }
}
