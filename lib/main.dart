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
import 'services/ai_services.dart';
import 'config/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase config required for web
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBno3L2C16YTRrXWrNbwVqTZYriYKHLEnw",
      authDomain: "optiai-6cd49.firebaseapp.com",
      projectId: "optiai-6cd49",
      storageBucket: "optiai-6cd49.appspot.com",
      messagingSenderId: "576297972114",
      appId: "1:576297972114:web:ccfc479a208f0f0869d14b",
    ),
  );

  runApp(const OptiAIGlassesApp());
}

class OptiAIGlassesApp extends StatelessWidget {
  const OptiAIGlassesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Gemini & ESP32 & Classification model service
        Provider<AiService>(
          create: (_) => AiService(
            geminiApiKey: 'AIzaSyDyMvOXEv6_nyV-R6G4as2Mw34TuC0rr2E',
            esp32Url: Env.esp32Url(localEsp32Url: 'http://192.168.192.78/capture'),
            modelApiUrl: 'http://127.0.0.1:8080',
          ),
        ),

        // 2. Chat Provider
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            aiService: context.read<AiService>(),
          ),
        ),

        // 3. Voice, Navigation, Theme, Auth
        ChangeNotifierProvider(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
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
