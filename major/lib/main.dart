import 'package:flutter/material.dart';
import 'package:major/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/token_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  runApp(const MyApp());
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
        title: 'Digital Queue Management',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const SplashScreen(),

      ),
    );
  }
}

