import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Load from environment variables - NEVER hardcode credentials!
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize() async {
    // Validate that required environment variables are present
    // (dotenv is already loaded in main.dart)
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'Missing Supabase configuration! Please ensure .env file exists with SUPABASE_URL and SUPABASE_ANON_KEY'
      );
    }
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
