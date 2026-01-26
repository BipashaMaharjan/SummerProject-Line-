import 'package:shared_preferences/shared_preferences.dart';

/// Rate limiter to prevent brute force attacks and spam
/// Tracks attempts per action type and enforces cooldown periods
class RateLimiter {
  static const String _keyPrefix = 'rate_limit_';
  
  // Rate limit configurations
  static const Map<String, RateLimitConfig> _configs = {
    'login': RateLimitConfig(maxAttempts: 5, windowMinutes: 15),
    'otp_request': RateLimitConfig(maxAttempts: 3, windowMinutes: 10),
    'token_creation': RateLimitConfig(maxAttempts: 5, windowMinutes: 60),
    'password_reset': RateLimitConfig(maxAttempts: 3, windowMinutes: 30),
  };

  /// Check if action is allowed
  /// Returns true if allowed, false if rate limited
  static Future<bool> isAllowed(String action, {String? identifier}) async {
    final config = _configs[action];
    if (config == null) return true; // No rate limit configured

    final key = _getKey(action, identifier);
    final prefs = await SharedPreferences.getInstance();
    
    final attemptsData = prefs.getString(key);
    if (attemptsData == null) {
      // First attempt
      await _recordAttempt(key, 1);
      return true;
    }

    final parts = attemptsData.split('|');
    final attempts = int.parse(parts[0]);
    final timestamp = DateTime.parse(parts[1]);
    
    // Check if window has expired
    final windowExpiry = timestamp.add(Duration(minutes: config.windowMinutes));
    if (DateTime.now().isAfter(windowExpiry)) {
      // Window expired, reset counter
      await _recordAttempt(key, 1);
      return true;
    }

    // Check if limit exceeded
    if (attempts >= config.maxAttempts) {
      return false; // Rate limited!
    }

    // Increment counter
    await _recordAttempt(key, attempts + 1, timestamp);
    return true;
  }

  /// Get remaining attempts before rate limit
  static Future<int> getRemainingAttempts(String action, {String? identifier}) async {
    final config = _configs[action];
    if (config == null) return 999; // No limit

    final key = _getKey(action, identifier);
    final prefs = await SharedPreferences.getInstance();
    
    final attemptsData = prefs.getString(key);
    if (attemptsData == null) return config.maxAttempts;

    final parts = attemptsData.split('|');
    final attempts = int.parse(parts[0]);
    final timestamp = DateTime.parse(parts[1]);
    
    // Check if window has expired
    final windowExpiry = timestamp.add(Duration(minutes: config.windowMinutes));
    if (DateTime.now().isAfter(windowExpiry)) {
      return config.maxAttempts;
    }

    return (config.maxAttempts - attempts).clamp(0, config.maxAttempts);
  }

  /// Get time until rate limit resets
  static Future<Duration?> getTimeUntilReset(String action, {String? identifier}) async {
    final config = _configs[action];
    if (config == null) return null;

    final key = _getKey(action, identifier);
    final prefs = await SharedPreferences.getInstance();
    
    final attemptsData = prefs.getString(key);
    if (attemptsData == null) return null;

    final parts = attemptsData.split('|');
    final attempts = int.parse(parts[0]);
    final timestamp = DateTime.parse(parts[1]);
    
    // Only return time if actually rate limited
    if (attempts < config.maxAttempts) return null;

    final windowExpiry = timestamp.add(Duration(minutes: config.windowMinutes));
    final now = DateTime.now();
    
    if (now.isAfter(windowExpiry)) return null;
    
    return windowExpiry.difference(now);
  }

  /// Reset rate limit for an action (admin use)
  static Future<void> reset(String action, {String? identifier}) async {
    final key = _getKey(action, identifier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Get user-friendly error message
  static Future<String> getRateLimitMessage(String action, {String? identifier}) async {
    final config = _configs[action];
    if (config == null) return 'Too many attempts. Please try again later.';

    final timeUntilReset = await getTimeUntilReset(action, identifier: identifier);
    if (timeUntilReset == null) {
      return 'Too many attempts. Please try again later.';
    }

    final minutes = timeUntilReset.inMinutes;
    final seconds = timeUntilReset.inSeconds % 60;

    if (minutes > 0) {
      return 'Too many attempts. Please wait $minutes minute${minutes > 1 ? 's' : ''} before trying again.';
    } else {
      return 'Too many attempts. Please wait $seconds second${seconds > 1 ? 's' : ''} before trying again.';
    }
  }

  // Private helpers

  static String _getKey(String action, String? identifier) {
    return '$_keyPrefix${action}_${identifier ?? 'default'}';
  }

  static Future<void> _recordAttempt(String key, int attempts, [DateTime? timestamp]) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = timestamp ?? DateTime.now();
    await prefs.setString(key, '$attempts|${ts.toIso8601String()}');
  }
}

/// Rate limit configuration
class RateLimitConfig {
  final int maxAttempts;
  final int windowMinutes;

  const RateLimitConfig({
    required this.maxAttempts,
    required this.windowMinutes,
  });
}
