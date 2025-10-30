import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_home_screen.dart';
import '../theme/app_fonts.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/animated_avatar.dart';

/// A screen for user authentication, handling both login and sign-up.
///
/// This widget features a futuristic, glassmorphism design with animations.
/// It includes a form for email and password input, validation, and interaction
/// with the [AuthProvider] to perform authentication.
class AuthScreen extends StatefulWidget {
  /// Creates a const [AuthScreen].
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// The state for the [AuthScreen].
///
/// Manages the form state, animations, and the logic for toggling between
/// login and sign-up modes. It also handles the authentication process
/// and displays feedback to the user (e.g., loading indicators, success/error messages).
class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool isLogin = true;
  bool isLoading = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _glowController;
  late final Animation<Color?> _glowColor;
  late final AnimationController _flipController;

  /// A getter that returns `true` if the user is typing in the email field.
  bool get isTypingEmail => emailController.text.isNotEmpty;
  /// A getter that returns `true` if the user is typing in the password field.
  bool get isTypingPassword => passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowColor = ColorTween(
      begin: const Color.fromARGB(255, 23, 24, 24).withOpacity(0.3),
      end: Colors.cyanAccent.withOpacity(0.7),
    ).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    emailController.addListener(() => setState(() {}));
    passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _glowController.dispose();
    _flipController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Toggles the form between login and sign-up modes.
  ///
  /// This method updates the UI state, clears the input fields, and
  /// triggers a flip animation to transition between the two forms.
  void toggleForm() {
    setState(() {
      isLogin = !isLogin;
      emailController.clear();
      passwordController.clear();
    });

    if (_flipController.status == AnimationStatus.dismissed ||
        _flipController.status == AnimationStatus.reverse) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  /// Handles the authentication process when the user submits the form.
  ///
  /// Validates the form fields, calls the appropriate method on the [AuthProvider],
  /// and displays feedback based on the result. On success, it navigates
  /// to the [ChatHomeScreen]. On failure, it shows a snackbar with an error message.
  ///
  /// [context] The build context for accessing providers and showing dialogs.
  Future<void> handleAuth(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => isLoading = true);

    final result = isLogin
        ? await auth.login(email, password)
        : await auth.signUp(email, password);

    setState(() => isLoading = false);

    if (result == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.2).animate(
              CurvedAnimation(
                parent: _glowController,
                curve: Curves.easeInOut,
              ),
            ),
            child: const AlertDialog(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
                  SizedBox(height: 10),
                  Text("Success!", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result,
                  style: AppFonts.body.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Builds the authentication form widget.
  ///
  /// This includes the email and password fields, the submit button, and the
  /// button to toggle between login and sign-up. It also features an animated
  /// avatar that responds to user input.
  Widget buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                child: Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.4),
                        blurRadius: 25,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedAvatar(
                isLookingLeft: isTypingEmail,
                isWearingGlasses: isTypingPassword,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isLogin ? 'Login' : 'Sign Up',
            style: AppFonts.heading.copyWith(fontSize: 26, color: Colors.white),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: emailController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 30),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.7),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : () => handleAuth(context),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isLogin ? 'Login' : 'Sign Up',
                        style: AppFonts.body.copyWith(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: toggleForm,
            child: Text(
              isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login",
              style: AppFonts.body.copyWith(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (_, __) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 360,
                  height: 500,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor.value ?? Colors.cyanAccent,
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 360,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      child: AnimatedBuilder(
                        animation: _flipController,
                        builder: (context, child) {
                          final angle = _flipController.value * math.pi;
                          final isBack = angle > math.pi / 2;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(angle),
                            child: isBack
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(math.pi),
                                    child: buildAuthForm(),
                                  )
                                : buildAuthForm(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
