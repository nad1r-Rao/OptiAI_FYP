import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_home_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth_screen.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

class AgentLoadingScreen extends StatefulWidget {
  const AgentLoadingScreen({super.key});

  @override
  State<AgentLoadingScreen> createState() => _AgentLoadingScreenState();
}

class _AgentLoadingScreenState extends State<AgentLoadingScreen> with TickerProviderStateMixin {
  final List<String> _loadingMessages = [
    "Initializing OptiAI Protocol...",
    "Establishing Secure Connection...",
    "Calibrating Neural Sensors...",
    "Enhancing User Interface...",
    "Welcome, To OptiAI Agent."
  ];

  int _currentMessageIndex = 0;
  String? _customMessage; // To show success/fail message
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Text Fade Animation
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textFadeController, curve: Curves.easeIn),
    );

    // Circle Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startLoadingSequence();
  }

  void _startLoadingSequence() async {
    for (int i = 0; i < _loadingMessages.length; i++) {
      if (!mounted) return;
      
      setState(() {
        _currentMessageIndex = i;
        _customMessage = null;
      });
      
      await _textFadeController.forward(from: 0.0);
      
      // Real Connection Check at index 1
      if (i == 1) {
        await Future.delayed(const Duration(milliseconds: 1000)); // Simulate work
        
        final connectivityResult = await Connectivity().checkConnectivity();
        final hasConnection = !connectivityResult.contains(ConnectivityResult.none);

        if (hasConnection) {
          if (!mounted) return;
          
          String connectionType = "UNKNOWN LINK";
          if (connectivityResult.contains(ConnectivityResult.wifi)) {
            connectionType = "SECURE WIFI LINK";
          } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
            connectionType = "CELLULAR DATA UPLINK";
          } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
            connectionType = "HARDWIRED ETHERNET";
          }

          setState(() {
            _customMessage = "Connection Established: $connectionType";
          });
          await Future.delayed(const Duration(milliseconds: 1500)); // Show success
        } else {
           if (!mounted) return;
           setState(() {
            _customMessage = "Connection Failed. Retrying...";
          });
          await Future.delayed(const Duration(milliseconds: 2000));
          // Proceed anyway for now, or loop retry (keeping it simple as per request)
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 800)); // Wait reading time
      }
      
      if (i < _loadingMessages.length - 1) {
        await _textFadeController.reverse();
      }
    }

    // Email Verification Check
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.reloadUser(); // Refresh status
    final user = auth.user;

    if (user != null && !user.emailVerified) {
      if (!mounted) return;
      
      setState(() {
        _customMessage = "Identity Verification Required";
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Email Verification", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Please verify your email address to access the agent interface.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () async {
                final msg = await auth.sendEmailVerification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg ?? "Verification email sent!")),
                  );
                }
              },
              child: const Text("Resend Email", style: TextStyle(color: Colors.cyanAccent)),
            ),
            TextButton(
              onPressed: () async {
                await auth.reloadUser();
                if (auth.user?.emailVerified == true) {
                  Navigator.pop(context);
                  _proceedToHome();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Email not verified yet.")),
                    );
                  }
                }
              },
              child: const Text("I've Verified", style: TextStyle(color: Colors.greenAccent)),
            ),
          ],
        ),
      );
    } else {
      _proceedToHome();
    }
  }

  void _proceedToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (_, __, ___) => const ChatHomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _textFadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sci-fi Loader
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.neonBlue.withOpacity(0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonBlue.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonBlue,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            
            // Loading Text
            FadeTransition(
              opacity: _textFadeAnimation,
              child: Text(
                _customMessage ?? _loadingMessages[_currentMessageIndex],
                style: AppFonts.code.copyWith(
                  color: _customMessage != null && _customMessage!.contains("Connection Established") 
                      ? AppColors.neonGreen 
                      : AppColors.neonBlue,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
