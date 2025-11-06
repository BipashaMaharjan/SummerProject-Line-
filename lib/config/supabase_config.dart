import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://dyzlenxijqjltxgszkfk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5emxlbnhpanFqbHR4Z3N6a2ZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0NzEwNTEsImV4cCI6MjA3MjA0NzA1MX0.Yp30L0Z1byFXSKaW8oQhrw7ndH6K4cQL5530IFTWSYY';
  static SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
