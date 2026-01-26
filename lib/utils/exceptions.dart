/// Custom exception classes for better error handling
/// Provides specific error types with user-friendly messages

/// Base exception class
abstract class AppException implements Exception {
  final String message;
  final String? userMessage;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.userMessage,
    this.originalError,
    this.stackTrace,
  });

  /// Get user-friendly error message
  String getUserMessage() => userMessage ?? message;

  @override
  String toString() => 'AppException: $message';
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Network error occurred',
          userMessage: userMessage ?? 'Please check your internet connection and try again',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Authentication exceptions
class AuthException extends AppException {
  AuthException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Authentication error',
          userMessage: userMessage ?? 'Please log in again to continue',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Database/Supabase exceptions
class DatabaseException extends AppException {
  DatabaseException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Database error occurred',
          userMessage: userMessage ?? 'Something went wrong. Please try again',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Rate limit exceeded
class RateLimitException extends AppException {
  final Duration retryAfter;

  RateLimitException({
    required this.retryAfter,
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Rate limit exceeded',
          userMessage: userMessage ?? 'Too many attempts. Please wait before trying again',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException({
    String? message,
    String? userMessage,
    this.fieldErrors,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Validation failed',
          userMessage: userMessage ?? 'Please check your input and try again',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Permission denied
class PermissionException extends AppException {
  PermissionException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Permission denied',
          userMessage: userMessage ?? 'You do not have permission to perform this action',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Resource not found
class NotFoundException extends AppException {
  NotFoundException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Resource not found',
          userMessage: userMessage ?? 'The requested item could not be found',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Server error
class ServerException extends AppException {
  final int? statusCode;

  ServerException({
    this.statusCode,
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Server error occurred',
          userMessage: userMessage ?? 'Server error. Please try again later',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Timeout exception
class TimeoutException extends AppException {
  TimeoutException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Request timed out',
          userMessage: userMessage ?? 'Request took too long. Please try again',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Unknown/Generic exception
class UnknownException extends AppException {
  UnknownException({
    String? message,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'An unexpected error occurred',
          userMessage: userMessage ?? 'Something went wrong. Please try again',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
