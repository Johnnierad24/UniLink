import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://avdpjuwxhgrbctikddnx.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2ZHBqdXd4aGdyYmN0aWtkZG54Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4OTA3NjksImV4cCI6MjA5MDQ2Njc2OX0.ixLH7o33EPlmaOGMUitf41trWHOrnefQ3wkgEscH7ho';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
