import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

/// Service to manage holiday data and validation
class HolidayService {
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  // Cache for holidays
  List<DateTime> _holidayDates = [];
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(hours: 1);

  /// Fetch holidays from database
  Future<void> fetchHolidays() async {
    try {
      debugPrint('🔄 Fetching holidays from database...');
      
      final response = await SupabaseConfig.client
          .from('holidays')
          .select('date, is_active')
          .eq('is_active', true)
          .order('date', ascending: true);

      _holidayDates = (response as List)
          .map((holiday) => DateTime.parse(holiday['date'] as String))
          .toList();

      _lastFetchTime = DateTime.now();
      
      debugPrint('✅ Fetched ${_holidayDates.length} holidays');
    } catch (e) {
      debugPrint('❌ Error fetching holidays: $e');
      // Keep existing cache if fetch fails
    }
  }

  /// Get all holiday dates (fetches from DB if cache is stale)
  Future<List<DateTime>> getHolidayDates() async {
    // Refresh cache if it's stale or empty
    if (_lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) > _cacheDuration ||
        _holidayDates.isEmpty) {
      await fetchHolidays();
    }
    
    return _holidayDates;
  }

  /// Check if a specific date is a holiday
  Future<bool> isHoliday(DateTime date) async {
    final holidays = await getHolidayDates();
    
    // Normalize dates to compare only year, month, day
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    return holidays.any((holiday) {
      final normalizedHoliday = DateTime(holiday.year, holiday.month, holiday.day);
      return normalizedHoliday == normalizedDate;
    });
  }

  /// Check if a date is selectable for appointment (not weekend, not holiday)
  /// Note: In Nepal, Saturday is the weekend day (Sunday is a working day)
  Future<bool> isDateSelectableForAppointment(DateTime date) async {
    // Check if it's Saturday (Nepal's weekend)
    if (date.weekday == DateTime.saturday) {
      return false;
    }

    // Check if it's a holiday
    if (await isHoliday(date)) {
      return false;
    }

    return true;
  }

  /// Clear the cache (useful for testing or after holiday updates)
  void clearCache() {
    _holidayDates = [];
    _lastFetchTime = null;
    debugPrint('🗑️ Holiday cache cleared');
  }

  /// Get holidays within a date range
  Future<List<DateTime>> getHolidaysInRange(DateTime start, DateTime end) async {
    final holidays = await getHolidayDates();
    
    return holidays.where((holiday) {
      return holiday.isAfter(start.subtract(const Duration(days: 1))) &&
             holiday.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
}
