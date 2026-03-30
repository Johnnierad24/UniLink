import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/auth_provider.dart';
import 'core/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const UniLinkApp(),
    ),
  );
}
