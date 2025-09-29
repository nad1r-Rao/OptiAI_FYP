import 'package:flutter/material.dart';
import 'auth_screen.dart';
import '../theme/app_fonts.dart';
import '../theme/app_colors.dart';
// import 'package:animated_text_kit/animated_text_kit.dart'; // <-- Add this import


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Bouncing Animation
    _bounceController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Glow Pulse Animation
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Text Fade + Slide Animation (make slower now)
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // <-- 2 seconds
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textFadeController, curve: Curves.easeInOut),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeOut,
    ));

    _textFadeController.forward(); // Start smooth animation

    // Navigate to Auth Screen after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const AuthScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    _textFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonBlue.withOpacity(0.6),
                              blurRadius: 30 * _glowAnimation.value,
                              spreadRadius: 10 * _glowAnimation.value,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/glasses.png',
                          width: 200,
                          height: 200,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SlideTransition(
              position: _textSlideAnimation,
              child: FadeTransition(
                opacity: _textFadeAnimation,
                child: Text(
                  'OptiAI',
                  style: AppFonts.heading.copyWith(
                    color: AppColors.neonBlue,
                    fontSize: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
