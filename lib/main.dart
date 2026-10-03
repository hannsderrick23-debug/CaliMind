import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/supabase_client.dart';
import 'core/services/push_notification_service.dart';

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
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF7F4FA),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Configure these public project values at build time when using another
  // Supabase project; the Groq secret stays in the Edge Function environment.
  await SupabaseConfig.initialize(
    customUrl: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ehntfznnwqnbfekkojcf.supabase.co',
    ),
    customPublishableKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_ChDmtcte4IKvLpOvAboh5A_v1yToL8M',
    ),
  );
  await PushNotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: CaliMindApp(),
    ),
  );
}
