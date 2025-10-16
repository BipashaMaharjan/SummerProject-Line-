import '../config/supabase_config.dart';

class DatabaseInspector {
  /// Check if a table exists in the database
  static Future<bool> tableExists(String tableName) async {
    try {
      final response = await SupabaseConfig.client
          .from(tableName)
          .select()
          .limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get table schema information
  static Future<Map<String, dynamic>?> getTableSchema(String tableName) async {
    try {
      // Try to get a sample record to understand the structure
      final response = await SupabaseConfig.client
          .from(tableName)
          .select()
          .limit(1);

      if (response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting table schema for $tableName: $e');
      return null;
    }
  }

  /// Check if a column exists in a table
  static Future<bool> columnExists(String tableName, String columnName) async {
    try {
      final schema = await getTableSchema(tableName);
      return schema?.containsKey(columnName) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get all tables in the database
  static Future<List<String>> getAllTables() async {
    try {
      // This is a simple approach - try common table names
      final commonTables = [
        'tokens', 'services', 'rooms', 'service_workflow',
        'token_history', 'profiles', 'holidays', 'staff'
      ];

      final existingTables = <String>[];
      for (final table in commonTables) {
        if (await tableExists(table)) {
          existingTables.add(table);
        }
      }

      return existingTables;
    } catch (e) {
      print('Error getting all tables: $e');
      return [];
    }
  }

  /// Comprehensive database health check
  static Future<Map<String, dynamic>> performHealthCheck() async {
    final healthReport = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
      'issues': <String>[],
      'recommendations': <String>[],
    };

    // Check all expected tables
    final expectedTables = [
      'tokens', 'services', 'rooms', 'service_workflow',
      'token_history', 'profiles', 'holidays', 'staff'
    ];

    for (final tableName in expectedTables) {
      final exists = await tableExists(tableName);
      healthReport['tables'][tableName] = {
        'exists': exists,
        'schema': exists ? await getTableSchema(tableName) : null,
      };

      if (!exists) {
        healthReport['issues'].add('Table $tableName does not exist');
        healthReport['recommendations'].add('Create table $tableName using the schema script');
      }
    }

    // Check critical columns for tokens table
    if (healthReport['tables']['tokens']['exists'] == true) {
      final tokenSchema = healthReport['tables']['tokens']['schema'] as Map<String, dynamic>?;

      final criticalColumns = [
        'token_number', 'user_id', 'service_id', 'status',
        'current_room_id', 'estimated_wait_minutes', 'booked_at'
      ];

      for (final column in criticalColumns) {
        final exists = tokenSchema?.containsKey(column) ?? false;
        if (!exists) {
          healthReport['issues'].add('Column $column missing from tokens table');
          healthReport['recommendations'].add('Add column $column to tokens table');
        }
      }
    }

    return healthReport;
  }

  /// Print formatted health report
  static void printHealthReport(Map<String, dynamic> report) {
    print('\n=== DATABASE HEALTH REPORT ===');
    print('Generated: ${report['timestamp']}');

    print('\nTABLES STATUS:');
    final tables = report['tables'] as Map<String, dynamic>;
    tables.forEach((tableName, tableInfo) {
      final info = tableInfo as Map<String, dynamic>;
      final exists = info['exists'] as bool;
      final status = exists ? '✅ EXISTS' : '❌ MISSING';
      print('  $tableName: $status');

      if (exists && info['schema'] != null) {
        final schema = info['schema'] as Map<String, dynamic>;
        print('    Columns: ${schema.keys.join(', ')}');
      }
    });

    print('\nISSUES FOUND:');
    final issues = report['issues'] as List<String>;
    if (issues.isEmpty) {
      print('  ✅ No issues found');
    } else {
      issues.forEach((issue) => print('  ❌ $issue'));
    }

    print('\nRECOMMENDATIONS:');
    final recommendations = report['recommendations'] as List<String>;
    if (recommendations.isEmpty) {
      print('  ✅ No recommendations');
    } else {
      recommendations.forEach((rec) => print('  💡 $rec'));
    }

    print('\n=== END REPORT ===\n');
  }
}