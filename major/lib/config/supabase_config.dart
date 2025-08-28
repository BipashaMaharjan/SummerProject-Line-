import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://mldlqkxchilmwgeydwle.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZGxxa3hjaGlsbXdnZXlkd2xlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2NzcwNjYsImV4cCI6MjA2ODI1MzA2Nn0.QjD5zlcq2_sEvmGZEMntVMKlekd-atTX14lcHiOS2s0';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}
