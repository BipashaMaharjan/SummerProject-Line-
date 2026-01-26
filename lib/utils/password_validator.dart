/// Password validation utility
/// Enforces strong password requirements for security
class PasswordValidator {
  // Minimum password length
  static const int minLength = 8;
  
  // Common weak passwords to reject
  static const List<String> commonPasswords = [
    'password', 'password123', '12345678', 'qwerty', 'abc123',
    'letmein', 'welcome', 'monkey', '1234567890', 'password1',
    'admin', 'admin123', 'root', 'toor', 'pass', 'test', 'guest',
  ];

  /// Validates password strength
  /// Returns null if valid, error message if invalid
  static String? validate(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }

    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    // Check for common weak passwords
    if (commonPasswords.contains(password.toLowerCase())) {
      return 'This password is too common. Please choose a stronger password';
    }

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check for at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character (!@#\$%^&*...)';
    }

    return null; // Password is valid
  }

  /// Gets password strength as a percentage (0-100)
  static int getStrength(String password) {
    int strength = 0;

    if (password.length >= minLength) strength += 20;
    if (password.length >= 12) strength += 10;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 20;
    if (password.contains(RegExp(r'[a-z]'))) strength += 20;
    if (password.contains(RegExp(r'[0-9]'))) strength += 15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 15;

    return strength.clamp(0, 100);
  }

  /// Gets password strength label
  static String getStrengthLabel(int strength) {
    if (strength < 40) return 'Weak';
    if (strength < 70) return 'Medium';
    return 'Strong';
  }

  /// Gets color for password strength indicator
  static String getStrengthColor(int strength) {
    if (strength < 40) return 'red';
    if (strength < 70) return 'orange';
    return 'green';
  }

  /// Generates password requirements text
  static String getRequirementsText() {
    return '''
Password must:
• Be at least $minLength characters long
• Contain at least one uppercase letter (A-Z)
• Contain at least one lowercase letter (a-z)
• Contain at least one number (0-9)
• Contain at least one special character (!@#\$%^&*...)
• Not be a common password
''';
  }
}
