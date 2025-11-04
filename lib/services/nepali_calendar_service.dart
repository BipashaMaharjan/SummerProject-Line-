import 'package:flutter/foundation.dart';
import 'package:nepali_utils/nepali_utils.dart';

/// Service to handle Nepali calendar conversions and formatting
class NepaliCalendarService {
  static final NepaliCalendarService _instance = NepaliCalendarService._internal();
  factory NepaliCalendarService() => _instance;
  NepaliCalendarService._internal();

  /// Convert English date to Nepali date
  NepaliDateTime toNepaliDate(DateTime englishDate) {
    return NepaliDateTime.fromDateTime(englishDate);
  }

  /// Convert Nepali date to English date
  DateTime toEnglishDate(NepaliDateTime nepaliDate) {
    return nepaliDate.toDateTime();
  }

  /// Format date to show both English and Nepali
  String formatDualDate(DateTime englishDate) {
    final nepaliDate = toNepaliDate(englishDate);
    
    // English format: "25 Dec 2024"
    final englishFormatted = _formatEnglishDate(englishDate);
    
    // Nepali format: "१० पुष २०८१" (10 Poush 2081)
    final nepaliFormatted = NepaliDateFormat('dd MMMM yyyy', Language.nepali).format(nepaliDate);
    
    return '$englishFormatted\n$nepaliFormatted';
  }

  /// Format date for display (English with Nepali in parentheses)
  String formatDateWithNepali(DateTime englishDate) {
    final nepaliDate = toNepaliDate(englishDate);
    final englishFormatted = _formatEnglishDate(englishDate);
    final nepaliFormatted = NepaliDateFormat('dd MMMM yyyy', Language.nepali).format(nepaliDate);
    
    return '$englishFormatted ($nepaliFormatted)';
  }

  /// Format only Nepali date
  String formatNepaliDate(DateTime englishDate) {
    final nepaliDate = toNepaliDate(englishDate);
    return NepaliDateFormat('dd MMMM yyyy', Language.nepali).format(nepaliDate);
  }

  /// Format only English date
  String _formatEnglishDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Get current Nepali date
  NepaliDateTime getCurrentNepaliDate() {
    return NepaliDateTime.now();
  }

  /// Get Nepali month name in English
  String getNepaliMonthNameEnglish(int month) {
    const months = [
      'Baishakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra', 'Ashwin',
      'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'
    ];
    return months[month - 1];
  }

  /// Get Nepali month name in Nepali
  String getNepaliMonthNameNepali(int month) {
    const months = [
      'बैशाख', 'जेठ', 'असार', 'श्रावण', 'भाद्र', 'आश्विन',
      'कार्तिक', 'मंसिर', 'पुष', 'माघ', 'फाल्गुन', 'चैत्र'
    ];
    return months[month - 1];
  }

  /// Check if a Nepali date is a major festival/holiday
  /// This is a basic implementation - you can expand with actual festival dates
  bool isMajorNepaliHoliday(NepaliDateTime nepaliDate) {
    // Dashain (Vijaya Dashami) - Ashwin 10
    if (nepaliDate.month == 7 && nepaliDate.day == 10) {
      return true;
    }
    
    // Tihar (Laxmi Puja) - Kartik 15
    if (nepaliDate.month == 8 && nepaliDate.day == 15) {
      return true;
    }
    
    // Nepali New Year - Baishakh 1
    if (nepaliDate.month == 1 && nepaliDate.day == 1) {
      return true;
    }
    
    return false;
  }

  /// Get festival name if the date is a major festival
  String? getFestivalName(DateTime englishDate) {
    final nepaliDate = toNepaliDate(englishDate);
    
    if (nepaliDate.month == 7 && nepaliDate.day == 10) {
      return 'Vijaya Dashami (Dashain)';
    }
    
    if (nepaliDate.month == 8 && nepaliDate.day == 15) {
      return 'Laxmi Puja (Tihar)';
    }
    
    if (nepaliDate.month == 1 && nepaliDate.day == 1) {
      return 'Nepali New Year';
    }
    
    return null;
  }

  /// Format date for calendar display (short format)
  String formatCalendarDate(DateTime englishDate) {
    final nepaliDate = toNepaliDate(englishDate);
    
    // English: "25 Dec"
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final englishShort = '${englishDate.day} ${months[englishDate.month - 1]}';
    
    // Nepali: "१० पुष"
    final nepaliShort = NepaliDateFormat('dd MMM', Language.nepali).format(nepaliDate);
    
    return '$englishShort\n$nepaliShort';
  }

  /// Get day name in Nepali
  String getNepaliDayName(DateTime date) {
    const days = [
      'सोमबार',    // Monday
      'मंगलबार',   // Tuesday
      'बुधबार',    // Wednesday
      'बिहिबार',   // Thursday
      'शुक्रबार',  // Friday
      'शनिबार',    // Saturday
      'आइतबार'     // Sunday
    ];
    return days[date.weekday - 1];
  }

  /// Get day name in English
  String getEnglishDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  /// Format complete date with day name
  String formatCompleteDate(DateTime englishDate) {
    final nepaliDate = toNepaliDate(englishDate);
    final dayName = getEnglishDayName(englishDate);
    final nepaliDayName = getNepaliDayName(englishDate);
    
    final englishFormatted = _formatEnglishDate(englishDate);
    final nepaliFormatted = NepaliDateFormat('dd MMMM yyyy', Language.nepali).format(nepaliDate);
    
    return '$dayName, $englishFormatted\n$nepaliDayName, $nepaliFormatted';
  }

  /// Check if date is Saturday (Nepal's weekend)
  bool isSaturday(DateTime date) {
    return date.weekday == DateTime.saturday;
  }

  /// Check if date is Sunday (working day in Nepal)
  bool isSunday(DateTime date) {
    return date.weekday == DateTime.sunday;
  }

  /// Get working days info
  String getWorkingDaysInfo() {
    return 'Working Days: Sunday - Friday\nWeekend: Saturday';
  }
}
