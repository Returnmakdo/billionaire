import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://nwndjqgipjlxxoxptusn.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53bmRqcWdpcGpseHhveHB0dXNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNzI1NTEsImV4cCI6MjA5Mjg0ODU1MX0.0FbipuhoAs-r8L4x-FDeBgjKytI0hoSFRb7dFebUE44';

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

SupabaseClient get sb => Supabase.instance.client;
