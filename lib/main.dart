import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:major/screens/splash_screen.dart';
import 'package:major/screens/admin/admin_login_screen.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/token_provider.dart';

// Global config
late final Map<String, dynamic> appConfig;
bool isAdminMode = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check for admin mode
  try {
    // For web, use environment variables
    if (kIsWeb) {
      isAdminMode = const String.fromEnvironment('APP_TYPE', defaultValue: '') == 'admin';
    } 
    // For other platforms, use command line arguments
    else {
      final args = Platform.executableArguments;
      isAdminMode = args.contains('--admin');
    }

    // Load appropriate config based on mode
    final configFile = isAdminMode ? 'admin_config.json' : 'user_config.json';
    try {
      final configString = await rootBundle.loadString(configFile);
      appConfig = json.decode(configString) as Map<String, dynamic>;
    } catch (e) {
      // Fallback to default config if file not found
      appConfig = {
        'APP_MODE': isAdminMode ? 'admin' : 'user',
        'APP_NAME': isAdminMode ? 'Admin - Digital Queue' : 'Digital Queue Management',
      };
    }

    // Initialize Supabase
    await SupabaseConfig.initialize();
    
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to initialize app: $e')),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TokenProvider()),
      ],
      child: MaterialApp(
        title: isAdminMode ? 'Admin - Digital Queue' : 'Digital Queue Management',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: isAdminMode ? Colors.purple : Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: isAdminMode ? const AdminLoginScreen() : const SplashScreen(),
      ),
    );
  }
}