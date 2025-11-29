import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'providers/chat_provider.dart';
import 'providers/speech_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/memory_provider.dart'; // Added import
import 'services/ai_services.dart';
import 'config/env.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added import

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load environment variables

  // Firebase config required for web
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
      authDomain: "optiai-6cd49.firebaseapp.com",
      projectId: "optiai-6cd49",
      storageBucket: "optiai-6cd49.appspot.com",
      messagingSenderId: "576297972114",
      appId: "1:576297972114:web:ccfc479a208f0f0869d14b",
    ),
  );

  runApp(const OptiAIGlassesApp());
}

class OptiAIGlassesApp extends StatefulWidget {
  const OptiAIGlassesApp({super.key});

  @override
  State<OptiAIGlassesApp> createState() => _OptiAIGlassesAppState();
}

class _OptiAIGlassesAppState extends State<OptiAIGlassesApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If any of the results is not none, we have connection (simplification)
      // Or check if results.contains(ConnectivityResult.none)
      
      bool hasConnection = !results.contains(ConnectivityResult.none);
      
      if (!hasConnection) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text("No Internet Connection"),
            backgroundColor: Colors.red,
            duration: Duration(days: 1), // Persistent until connected
          ),
        );
      } else {
        _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
        // Optional: Show "Back Online" briefly
        // _scaffoldMessengerKey.currentState?.showSnackBar(
        //   const SnackBar(
        //     content: Text("Back Online"),
        //     backgroundColor: Colors.green,
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Gemini & ESP32 & Classification model service
        Provider<AiService>(
          create: (_) => AiService(
            geminiApiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
            esp32Url: Env.esp32Url(localEsp32Url: 'http://esp32cam.local/capture'),
            modelApiUrl: 'http://127.0.0.1:8080',
          ),
        ),

        // 2. Memory Provider
        ChangeNotifierProvider(create: (_) => MemoryProvider()),

        // 3. Chat Provider (depends on AiService and MemoryProvider)
        ChangeNotifierProxyProvider2<AiService, MemoryProvider, ChatProvider>(
          create: (context) => ChatProvider(
            aiService: context.read<AiService>(),
            memoryProvider: context.read<MemoryProvider>(),
          ),
          update: (context, aiService, memoryProvider, previous) =>
              previous ?? ChatProvider(aiService: aiService, memoryProvider: memoryProvider),
        ),

        // 4. Other Providers
        ChangeNotifierProvider(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            scaffoldMessengerKey: _scaffoldMessengerKey,
            title: 'OptiAI Glasses',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              scaffoldBackgroundColor: Colors.white,
              fontFamily: 'Roboto',
              colorScheme: ColorScheme.fromSwatch().copyWith(
                primary: Colors.blue,
                secondary: Colors.green,
              ),
              textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.black,
                    displayColor: Colors.black,
                  ),
            ),
            darkTheme: ThemeData(
              scaffoldBackgroundColor: AppColors.background,
              fontFamily: 'Roboto',
              colorScheme: ColorScheme.dark().copyWith(
                primary: AppColors.neonBlue,
                secondary: AppColors.neonGreen,
              ),
              textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: AppColors.softWhite,
                    displayColor: AppColors.softWhite,
                  ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
