import 'package:flutter/foundation.dart';
import '../services/holiday_service.dart';

/// Utility class to test holiday functionality
class HolidayTestUtility {
  static final HolidayService _holidayService = HolidayService();

  /// Test holiday service functionality
  static Future<void> runTests() async {
    debugPrint('🧪 Starting Holiday Service Tests...\n');

    await _testFetchHolidays();
    await _testIsHoliday();
    await _testIsDateSelectable();
    await _testWeekendHandling();
    await _testCacheClearing();

    debugPrint('\n✅ All Holiday Service Tests Completed!');
  }

  static Future<void> _testFetchHolidays() async {
    debugPrint('📋 Test 1: Fetch Holidays');
    try {
      final holidays = await _holidayService.getHolidayDates();
      debugPrint('   ✅ Fetched ${holidays.length} holidays');
      
      if (holidays.isNotEmpty) {
        debugPrint('   📅 First holiday: ${holidays.first}');
        debugPrint('   📅 Last holiday: ${holidays.last}');
      } else {
        debugPrint('   ⚠️ No holidays configured in database');
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    debugPrint('');
  }

  static Future<void> _testIsHoliday() async {
    debugPrint('📋 Test 2: Check if Date is Holiday');
    try {
      // Test today
      final today = DateTime.now();
      final isTodayHoliday = await _holidayService.isHoliday(today);
      debugPrint('   Today (${_formatDate(today)}): ${isTodayHoliday ? "Holiday 🎉" : "Working Day 💼"}');

      // Test a few future dates
      for (int i = 1; i <= 7; i++) {
        final futureDate = today.add(Duration(days: i));
        final isHoliday = await _holidayService.isHoliday(futureDate);
        debugPrint('   ${_formatDate(futureDate)}: ${isHoliday ? "Holiday 🎉" : "Working Day 💼"}');
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    debugPrint('');
  }

  static Future<void> _testIsDateSelectable() async {
    debugPrint('📋 Test 3: Check if Date is Selectable for Appointment');
    try {
      final today = DateTime.now();
      
      for (int i = 0; i <= 14; i++) {
        final date = today.add(Duration(days: i));
        final isSelectable = await _holidayService.isDateSelectableForAppointment(date);
        final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
        final isHoliday = await _holidayService.isHoliday(date);
        
        String reason = '';
        if (!isSelectable) {
          if (isWeekend) reason = '(Weekend)';
          if (isHoliday) reason = '(Holiday)';
        }
        
        debugPrint('   ${_formatDate(date)}: ${isSelectable ? "✅ Selectable" : "❌ Not Selectable $reason"}');
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    debugPrint('');
  }

  static Future<void> _testWeekendHandling() async {
    debugPrint('📋 Test 4: Weekend Handling');
    try {
      final today = DateTime.now();
      
      // Find next Saturday and Sunday
      DateTime? nextSaturday;
      DateTime? nextSunday;
      
      for (int i = 0; i <= 7; i++) {
        final date = today.add(Duration(days: i));
        if (date.weekday == DateTime.saturday && nextSaturday == null) {
          nextSaturday = date;
        }
        if (date.weekday == DateTime.sunday && nextSunday == null) {
          nextSunday = date;
        }
      }
      
      if (nextSaturday != null) {
        final isSelectable = await _holidayService.isDateSelectableForAppointment(nextSaturday);
        debugPrint('   Next Saturday (${_formatDate(nextSaturday)}): ${isSelectable ? "✅ Selectable" : "❌ Not Selectable"}');
      }
      
      if (nextSunday != null) {
        final isSelectable = await _holidayService.isDateSelectableForAppointment(nextSunday);
        debugPrint('   Next Sunday (${_formatDate(nextSunday)}): ${isSelectable ? "✅ Selectable" : "❌ Not Selectable"}');
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    debugPrint('');
  }

  static Future<void> _testCacheClearing() async {
    debugPrint('📋 Test 5: Cache Clearing');
    try {
      debugPrint('   🔄 Fetching holidays (should use cache)...');
      final holidays1 = await _holidayService.getHolidayDates();
      debugPrint('   ✅ Got ${holidays1.length} holidays from cache');
      
      debugPrint('   🗑️ Clearing cache...');
      _holidayService.clearCache();
      debugPrint('   ✅ Cache cleared');
      
      debugPrint('   🔄 Fetching holidays again (should fetch from DB)...');
      final holidays2 = await _holidayService.getHolidayDates();
      debugPrint('   ✅ Got ${holidays2.length} holidays from database');
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    debugPrint('');
  }

  static String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  /// Quick test for a specific date
  static Future<void> testSpecificDate(DateTime date) async {
    debugPrint('🧪 Testing date: ${_formatDate(date)}\n');
    
    final isHoliday = await _holidayService.isHoliday(date);
    final isSelectable = await _holidayService.isDateSelectableForAppointment(date);
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    
    debugPrint('   Is Holiday: ${isHoliday ? "Yes 🎉" : "No"}');
    debugPrint('   Is Weekend: ${isWeekend ? "Yes" : "No"}');
    debugPrint('   Is Selectable for Appointment: ${isSelectable ? "Yes ✅" : "No ❌"}');
    
    if (!isSelectable) {
      if (isWeekend) debugPrint('   Reason: Weekend');
      if (isHoliday) debugPrint('   Reason: Holiday');
    }
  }

  /// Test with sample holiday data
  static Future<void> testWithSampleData() async {
    debugPrint('🧪 Testing with Sample Holiday Scenarios...\n');

    // Test Christmas (assuming it might be a holiday)
    final christmas = DateTime(DateTime.now().year, 12, 25);
    debugPrint('📅 Testing Christmas:');
    await testSpecificDate(christmas);
    debugPrint('');

    // Test New Year
    final newYear = DateTime(DateTime.now().year + 1, 1, 1);
    debugPrint('📅 Testing New Year:');
    await testSpecificDate(newYear);
    debugPrint('');

    // Test a regular weekday
    final today = DateTime.now();
    DateTime? nextWeekday;
    for (int i = 1; i <= 7; i++) {
      final date = today.add(Duration(days: i));
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        nextWeekday = date;
        break;
      }
    }
    
    if (nextWeekday != null) {
      debugPrint('📅 Testing Next Weekday:');
      await testSpecificDate(nextWeekday);
      debugPrint('');
    }
  }
}
