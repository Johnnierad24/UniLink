import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/services/theme_provider.dart';
import 'core/services/auth_provider.dart';
import 'features/home/home_shell.dart';
import 'features/auth/login_screen.dart';

class UniLinkApp extends StatelessWidget {
  const UniLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'UniLink',
            theme: UniLinkTheme.light,
            darkTheme: UniLinkTheme.dark,
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (!auth.initialized) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return auth.isLoggedIn
                    ? const HomeShell()
                    : const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
