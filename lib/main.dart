import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'presentation/screens/main_navigation_screen.dart';

import 'core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase backend service at startup
  await SupabaseService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const SupaChatApp(),
    ),
  );
}

class SupaChatApp extends StatelessWidget {
  const SupaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'SupaChat Messenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: authProvider.isLoggedIn ? const MainNavigationScreen() : const AuthScreen(),
    );
  }
}
