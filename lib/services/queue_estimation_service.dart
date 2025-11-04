import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/token.dart';
import 'office_hours_service.dart';

/// Service for calculating queue position and estimated wait times
class QueueEstimationService {
  static final QueueEstimationService _instance = QueueEstimationService._internal();
  factory QueueEstimationService() => _instance;
  QueueEstimationService._internal();

  final OfficeHoursService _officeHours = OfficeHoursService();

  // Default average handling times per service (in minutes)
  static const Map<String, int> _defaultHandlingTimes = {
    'license_renewal': 15,
    'new_license': 25,
    'default': 20,
  };

  /// Get queue position for a token
  Future<int> getQueuePosition(Token token) async {
    try {
      if (token.status != TokenStatus.waiting) {
        return 0; // Not in queue
      }

      final response = await SupabaseConfig.client
          .from('tokens')
          .select('id')
          .eq('service_id', token.serviceId)
          .eq('status', 'waiting')
          .lt('created_at', token.createdAt.toIso8601String());

      return (response as List).length + 1;
    } catch (e) {
      debugPrint('QueueEstimationService: Error getting queue position: $e');
      return 0;
    }
  }

  /// Get number of tokens ahead in queue
  Future<int> getTokensAhead(Token token) async {
    try {
      if (token.status != TokenStatus.waiting) {
        return 0;
      }

      final response = await SupabaseConfig.client
          .from('tokens')
          .select('id')
          .eq('service_id', token.serviceId)
          .eq('status', 'waiting')
          .lt('created_at', token.createdAt.toIso8601String());

      return (response as List).length;
    } catch (e) {
      debugPrint('QueueEstimationService: Error getting tokens ahead: $e');
      return 0;
    }
  }

  /// Get currently processing token for the service
  Future<Map<String, dynamic>?> getCurrentlyProcessingToken(String serviceId) async {
    try {
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('id, started_at, created_at')
          .eq('service_id', serviceId)
          .eq('status', 'processing')
          .order('started_at', ascending: true)
          .limit(1);

      final tokens = response as List;
      if (tokens.isEmpty) {
        return null;
      }

      return tokens.first as Map<String, dynamic>;
    } catch (e) {
      debugPrint('QueueEstimationService: Error getting processing token: $e');
      return null;
    }
  }

  /// Calculate real-time countdown based on currently processing token
  Future<int> getRealTimeCountdown(Token token, int avgHandlingTime) async {
    try {
      // Get currently processing token
      final processingToken = await getCurrentlyProcessingToken(token.serviceId);
      
      if (processingToken == null) {
        // No one is being processed, use standard estimation
        final tokensAhead = await getTokensAhead(token);
        debugPrint('🔍 No processing token. Tokens ahead: $tokensAhead, Avg time: $avgHandlingTime min');
        debugPrint('📊 Estimated wait: ${tokensAhead * avgHandlingTime} minutes');
        return tokensAhead * avgHandlingTime;
      }

      // Get how long the current token has been processing
      // Database stores timestamps - parse and use as-is
      final startedAt = DateTime.parse(processingToken['started_at']);
      final now = DateTime.now();
      
      // Calculate difference - handle timezone by using absolute value if needed
      int processingMinutes = now.difference(startedAt).inMinutes;
      
      // If negative (timezone issue), use 0
      if (processingMinutes < 0) {
        debugPrint('⚠️ Negative processing time detected (timezone issue). Using 0.');
        processingMinutes = 0;
      }
      
      // Calculate remaining time for current token
      final remainingForCurrent = avgHandlingTime - processingMinutes;
      final remainingForCurrentClamped = remainingForCurrent > 0 ? remainingForCurrent : 0;
      
      // Get tokens ahead (excluding the one being processed)
      final tokensAhead = await getTokensAhead(token);
      
      debugPrint('🔍 Processing token found:');
      debugPrint('   Started: $startedAt');
      debugPrint('   Processing for: $processingMinutes minutes');
      debugPrint('   Avg handling time: $avgHandlingTime minutes');
      debugPrint('   Remaining for current: $remainingForCurrentClamped minutes');
      debugPrint('   Tokens ahead (waiting): $tokensAhead');
      debugPrint('   Calculation: $remainingForCurrentClamped + ($tokensAhead × $avgHandlingTime)');
      
      // Total countdown = remaining time for current + (tokens ahead * avg time)
      final totalCountdown = remainingForCurrentClamped + (tokensAhead * avgHandlingTime);
      
      debugPrint('📊 Total countdown: $totalCountdown minutes');
      
      return totalCountdown;
    } catch (e) {
      debugPrint('QueueEstimationService: Error calculating real-time countdown: $e');
      // Fallback to standard estimation
      final tokensAhead = await getTokensAhead(token);
      return tokensAhead * avgHandlingTime;
    }
  }

  /// Calculate average handling time for a service
  Future<int> getAverageHandlingTime(String serviceId) async {
    try {
      // Get completed tokens from the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final response = await SupabaseConfig.client
          .from('tokens')
          .select('started_at, completed_at')
          .eq('service_id', serviceId)
          .eq('status', 'completed')
          .gte('completed_at', sevenDaysAgo.toIso8601String())
          .not('started_at', 'is', null)
          .not('completed_at', 'is', null);

      final tokens = response as List;
      
      if (tokens.isEmpty) {
        // No historical data, use default
        return _getDefaultHandlingTime(serviceId);
      }

      // Calculate average processing time
      int totalMinutes = 0;
      int validCount = 0;

      for (var token in tokens) {
        try {
          final startedAt = DateTime.parse(token['started_at']);
          final completedAt = DateTime.parse(token['completed_at']);
          final duration = completedAt.difference(startedAt);
          
          // Only count reasonable durations (between 1 minute and 2 hours)
          if (duration.inMinutes >= 1 && duration.inMinutes <= 120) {
            totalMinutes += duration.inMinutes;
            validCount++;
          }
        } catch (e) {
          debugPrint('QueueEstimationService: Error parsing token times: $e');
        }
      }

      if (validCount == 0) {
        return _getDefaultHandlingTime(serviceId);
      }

      return (totalMinutes / validCount).round();
    } catch (e) {
      debugPrint('QueueEstimationService: Error calculating average handling time: $e');
      return _getDefaultHandlingTime(serviceId);
    }
  }

  /// Get default handling time based on service type
  int _getDefaultHandlingTime(String serviceId) {
    // Try to match service type from ID or use default
    return _defaultHandlingTimes['default']!;
  }

  /// Calculate estimated wait time in minutes
  Future<int> getEstimatedWaitTime(Token token) async {
    try {
      if (token.status != TokenStatus.waiting) {
        return 0;
      }

      // Get tokens ahead
      final tokensAhead = await getTokensAhead(token);
      
      if (tokensAhead == 0) {
        return 0; // Next in line
      }

      // Get average handling time
      final avgHandlingTime = await getAverageHandlingTime(token.serviceId);

      // Calculate estimated wait time
      // Formula: tokens_ahead * avg_handling_time
      final estimatedMinutes = tokensAhead * avgHandlingTime;

      return estimatedMinutes;
    } catch (e) {
      debugPrint('QueueEstimationService: Error calculating wait time: $e');
      return 0;
    }
  }

  /// Format wait time as human-readable string
  String formatWaitTime(int minutes) {
    if (minutes == 0) {
      return 'Next in line';
    } else if (minutes < 5) {
      return 'Less than 5 minutes';
    } else if (minutes < 60) {
      return '~$minutes minutes';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '~$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '~$hours ${hours == 1 ? 'hour' : 'hours'} $remainingMinutes min';
      }
    }
  }

  /// Get complete queue information for a token
  Future<QueueInfo> getQueueInfo(Token token) async {
    try {
      final queuePosition = await getQueuePosition(token);
      final tokensAhead = await getTokensAhead(token);
      final avgHandlingTime = await getAverageHandlingTime(token.serviceId);
      final estimatedWaitMinutes = await getEstimatedWaitTime(token);

      return QueueInfo(
        queuePosition: queuePosition,
        tokensAhead: tokensAhead,
        averageHandlingTimeMinutes: avgHandlingTime,
        estimatedWaitMinutes: estimatedWaitMinutes,
        estimatedWaitTime: formatWaitTime(estimatedWaitMinutes),
      );
    } catch (e) {
      debugPrint('QueueEstimationService: Error getting queue info: $e');
      return QueueInfo(
        queuePosition: 0,
        tokensAhead: 0,
        averageHandlingTimeMinutes: 20,
        estimatedWaitMinutes: 0,
        estimatedWaitTime: 'Calculating...',
      );
    }
  }

  /// Get estimated completion time
  DateTime? getEstimatedCompletionTime(int estimatedWaitMinutes) {
    if (estimatedWaitMinutes == 0) {
      return null;
    }
    return DateTime.now().add(Duration(minutes: estimatedWaitMinutes));
  }

  /// Format estimated completion time
  String formatCompletionTime(DateTime? completionTime) {
    if (completionTime == null) {
      return 'Soon';
    }

    final hour = completionTime.hour;
    final minute = completionTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $period';
  }

  /// Check if real-time tracking should be shown for a token
  bool canShowRealTimeTracking(Token token) {
    if (token.scheduledDate == null) {
      return false; // No scheduled date
    }

    return _officeHours.canShowRealTimeTracking(
      appointmentDate: token.scheduledDate!,
    );
  }

  /// Check if it's the appointment date (regardless of office hours)
  bool isAppointmentDate(Token token) {
    if (token.scheduledDate == null) {
      return false;
    }

    return _officeHours.isAppointmentDate(
      appointmentDate: token.scheduledDate!,
    );
  }

  /// Check if appointment is in the future
  bool isAppointmentInFuture(Token token) {
    if (token.scheduledDate == null) {
      return false;
    }

    return _officeHours.isAppointmentInFuture(
      appointmentDate: token.scheduledDate!,
    );
  }

  /// Get tracking status message
  String getTrackingStatusMessage(Token token) {
    if (token.scheduledDate == null) {
      return 'No appointment date';
    }

    return _officeHours.getTrackingAvailabilityMessage(
      appointmentDate: token.scheduledDate!,
    );
  }

  /// Get complete queue information with date/time awareness and real-time countdown
  Future<EnhancedQueueInfo> getEnhancedQueueInfo(Token token) async {
    try {
      // Get basic queue info
      final basicInfo = await getQueueInfo(token);
      
      // Check if we should show real-time estimation
      final showRealTime = canShowRealTimeTracking(token);
      final isToday = isAppointmentDate(token);
      final isFuture = isAppointmentInFuture(token);
      
      // Get office status
      final officeStatus = token.scheduledDate != null
          ? _officeHours.getOfficeStatusMessage()
          : 'No appointment date';
      
      final trackingMessage = getTrackingStatusMessage(token);

      // Get real-time countdown if tracking is active
      int realTimeCountdown = basicInfo.estimatedWaitMinutes;
      if (showRealTime && token.status == TokenStatus.waiting) {
        realTimeCountdown = await getRealTimeCountdown(
          token,
          basicInfo.averageHandlingTimeMinutes,
        );
      }

      return EnhancedQueueInfo(
        queueInfo: basicInfo,
        showRealTimeEstimation: showRealTime,
        isAppointmentToday: isToday,
        isAppointmentInFuture: isFuture,
        officeStatus: officeStatus,
        trackingAvailabilityMessage: trackingMessage,
        realTimeCountdownMinutes: realTimeCountdown,
      );
    } catch (e) {
      debugPrint('QueueEstimationService: Error getting enhanced queue info: $e');
      final basicInfo = await getQueueInfo(token);
      return EnhancedQueueInfo(
        queueInfo: basicInfo,
        showRealTimeEstimation: false,
        isAppointmentToday: false,
        isAppointmentInFuture: false,
        officeStatus: 'Unknown',
        trackingAvailabilityMessage: 'Status unavailable',
        realTimeCountdownMinutes: 0,
      );
    }
  }
}

/// Queue information model
class QueueInfo {
  final int queuePosition;
  final int tokensAhead;
  final int averageHandlingTimeMinutes;
  final int estimatedWaitMinutes;
  final String estimatedWaitTime;

  QueueInfo({
    required this.queuePosition,
    required this.tokensAhead,
    required this.averageHandlingTimeMinutes,
    required this.estimatedWaitMinutes,
    required this.estimatedWaitTime,
  });

  bool get isNextInLine => tokensAhead == 0;
  
  String get positionText {
    if (queuePosition == 0) return 'Not in queue';
    if (queuePosition == 1) return 'Next in line';
    return 'Position #$queuePosition';
  }

  String get tokensAheadText {
    if (tokensAhead == 0) return 'You\'re next!';
    if (tokensAhead == 1) return '1 person ahead';
    return '$tokensAhead people ahead';
  }
}

/// Enhanced queue information with date/time awareness
class EnhancedQueueInfo {
  final QueueInfo queueInfo;
  final bool showRealTimeEstimation;
  final bool isAppointmentToday;
  final bool isAppointmentInFuture;
  final String officeStatus;
  final String trackingAvailabilityMessage;
  final int realTimeCountdownMinutes;

  EnhancedQueueInfo({
    required this.queueInfo,
    required this.showRealTimeEstimation,
    required this.isAppointmentToday,
    required this.isAppointmentInFuture,
    required this.officeStatus,
    required this.trackingAvailabilityMessage,
    required this.realTimeCountdownMinutes,
  });

  /// Should show only status (not estimation)
  bool get showStatusOnly => !showRealTimeEstimation && isAppointmentToday;

  /// Should show "coming soon" message
  bool get showComingSoon => isAppointmentInFuture;

  /// Get display message based on state
  String get displayMessage {
    if (showRealTimeEstimation) {
      return 'Live tracking active';
    } else if (isAppointmentToday) {
      return officeStatus;
    } else if (isAppointmentInFuture) {
      return trackingAvailabilityMessage;
    } else {
      return 'Appointment date has passed';
    }
  }
}
