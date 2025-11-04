import 'package:flutter/foundation.dart';

/// Service to manage office hours and operational status
class OfficeHoursService {
  static final OfficeHoursService _instance = OfficeHoursService._internal();
  factory OfficeHoursService() => _instance;
  OfficeHoursService._internal();

  // Office hours configuration (Nepal time)
  static const int openingHour = 10; // 10:00 AM
  static const int closingHour = 17; // 5:00 PM (17:00)

  /// Check if office is currently open
  bool isOfficeOpen({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    final hour = now.hour;
    
    // Check if it's a working day (Sunday to Friday in Nepal)
    if (now.weekday == DateTime.saturday) {
      return false; // Saturday is weekend in Nepal
    }
    
    // Check if within office hours (10 AM to 5 PM)
    return hour >= openingHour && hour < closingHour;
  }

  /// Check if it's a working day (not Saturday in Nepal)
  bool isWorkingDay({DateTime? dateTime}) {
    final date = dateTime ?? DateTime.now();
    return date.weekday != DateTime.saturday;
  }

  /// Get office status message
  String getOfficeStatusMessage({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    
    if (!isWorkingDay(dateTime: now)) {
      return 'Office closed - Saturday (Weekend)';
    }
    
    if (isOfficeOpen(dateTime: now)) {
      return 'Office is open';
    }
    
    final hour = now.hour;
    if (hour < openingHour) {
      final minutesUntilOpen = (openingHour - hour) * 60 - now.minute;
      if (minutesUntilOpen < 60) {
        return 'Office opens in $minutesUntilOpen minutes';
      }
      return 'Office opens at ${_formatHour(openingHour)}';
    } else {
      return 'Office closed for today';
    }
  }

  /// Get opening time as formatted string
  String getOpeningTime() {
    return _formatHour(openingHour);
  }

  /// Get closing time as formatted string
  String getClosingTime() {
    return _formatHour(closingHour);
  }

  /// Get office hours range
  String getOfficeHours() {
    return '${_formatHour(openingHour)} - ${_formatHour(closingHour)}';
  }

  /// Format hour to 12-hour format
  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  /// Get minutes until office opens (returns null if already open or closed for the day)
  int? getMinutesUntilOpen({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    
    if (!isWorkingDay(dateTime: now)) {
      return null; // Not a working day
    }
    
    if (isOfficeOpen(dateTime: now)) {
      return 0; // Already open
    }
    
    final hour = now.hour;
    if (hour < openingHour) {
      return (openingHour - hour) * 60 - now.minute;
    }
    
    return null; // Office closed for the day
  }

  /// Get minutes until office closes (returns null if already closed)
  int? getMinutesUntilClose({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    
    if (!isOfficeOpen(dateTime: now)) {
      return null; // Not open
    }
    
    return (closingHour - now.hour) * 60 - now.minute;
  }

  /// Check if real-time tracking should be enabled
  /// (office is open and it's the appointment date)
  bool canShowRealTimeTracking({
    required DateTime appointmentDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    
    // Check if it's the appointment date
    final isAppointmentDate = now.year == appointmentDate.year &&
        now.month == appointmentDate.month &&
        now.day == appointmentDate.day;
    
    if (!isAppointmentDate) {
      return false;
    }
    
    // Check if office is open
    return isOfficeOpen(dateTime: now);
  }

  /// Check if it's the appointment date (regardless of office hours)
  bool isAppointmentDate({
    required DateTime appointmentDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    
    return now.year == appointmentDate.year &&
        now.month == appointmentDate.month &&
        now.day == appointmentDate.day;
  }

  /// Check if appointment date is in the future
  bool isAppointmentInFuture({
    required DateTime appointmentDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointment = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
    );
    
    return appointment.isAfter(today);
  }

  /// Check if appointment date is in the past
  bool isAppointmentInPast({
    required DateTime appointmentDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointment = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
    );
    
    return appointment.isBefore(today);
  }

  /// Get tracking availability message
  String getTrackingAvailabilityMessage({
    required DateTime appointmentDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    
    if (isAppointmentInFuture(appointmentDate: appointmentDate, currentTime: now)) {
      final daysUntil = appointmentDate.difference(now).inDays;
      if (daysUntil == 1) {
        return 'Live tracking available tomorrow';
      }
      return 'Live tracking available on appointment date';
    }
    
    if (isAppointmentDate(appointmentDate: appointmentDate, currentTime: now)) {
      if (isOfficeOpen(dateTime: now)) {
        return 'Live tracking active';
      } else {
        return getOfficeStatusMessage(dateTime: now);
      }
    }
    
    return 'Appointment date has passed';
  }

  /// Debug: Print office status
  void debugPrintStatus({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    debugPrint('🏢 Office Hours Status:');
    debugPrint('   Current Time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    debugPrint('   Office Hours: ${getOfficeHours()}');
    debugPrint('   Is Working Day: ${isWorkingDay(dateTime: now)}');
    debugPrint('   Is Office Open: ${isOfficeOpen(dateTime: now)}');
    debugPrint('   Status: ${getOfficeStatusMessage(dateTime: now)}');
  }
}
