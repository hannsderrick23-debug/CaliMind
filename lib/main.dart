import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System chrome styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF12161F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase with credentials from .env (injected at build time)
  // For local development, set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define
  await SupabaseConfig.initialize(
    customUrl: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ehntfznnwqnbfekkojcf.supabase.co',
    ),
    customAnonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_ChDmtcte4IKvLpOvAboh5A_v1yToL8M',
    ),
  );

  runApp(
    const ProviderScope(
      child: CaliMindApp(),
    ),
  );
}
