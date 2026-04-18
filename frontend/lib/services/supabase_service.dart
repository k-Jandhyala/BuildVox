import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  /// Keys must match `--dart-define=SUPABASE_URL=...` / `SUPABASE_ANON_KEY=...`.
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mkmrrenfekhlvxdiljpm.supabase.co',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rbXJyZW5mZWtobHZ4ZGlsanBtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDc0NDYsImV4cCI6MjA5MjAyMzQ0Nn0.RuffP7lejnfQoZuPYaFAxDk8Vqh8PQI3iuYZqdIkOTc',
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception(
        'Supabase is not configured. Pass --dart-define=SUPABASE_URL and '
        '--dart-define=SUPABASE_ANON_KEY when running the app.',
      );
    }

    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception('SupabaseService.initialize() must be called first.');
    }
    return Supabase.instance.client;
  }
}
