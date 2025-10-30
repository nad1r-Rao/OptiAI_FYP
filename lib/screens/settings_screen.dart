import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'chat_home_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart'; 
import 'auth_screen.dart'; 

/// A screen for managing user settings.
///
/// This widget provides options for toggling the theme, viewing application
/// details in an "About" dialog, and logging out of the application. It
/// interacts with the [ThemeProvider] and [AuthProvider] to manage these functionalities.
class SettingsScreen extends StatelessWidget {
  /// Creates a const [SettingsScreen].
  const SettingsScreen({super.key});

  /// Navigates back to the [ChatHomeScreen] and removes all previous routes.
  ///
  /// [context] The build context for navigation.
  void _goToChatHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
      (route) => false,
    );
  }

  /// Logs the current user out and navigates to the [AuthScreen].
  ///
  /// [context] The build context for accessing the [AuthProvider] and navigation.
  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? AppColors.background : Colors.white,
      appBar: AppBar(
        backgroundColor: themeProvider.isDarkMode ? AppColors.background : Colors.white,
        elevation: 0,
        title: Text(
          'Settings',
          style: AppFonts.heading.copyWith(
            color: themeProvider.isDarkMode ? AppColors.neonBlue : Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black),
          onPressed: () => _goToChatHome(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔁 Theme toggle
          ListTile(
            leading: Icon(Icons.dark_mode,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black),
            title: Text(
              "Dark Mode",
              style: AppFonts.body.copyWith(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (val) => themeProvider.toggleTheme(val),
            ),
          ),

          // ℹ️ About
          ListTile(
            leading: Icon(Icons.info_outline,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black),
            title: Text(
              "About OptiAI",
              style: AppFonts.body.copyWith(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "OptiAI Smart Glasses",
                applicationVersion: "v1.0.0",
                children: const [
                  Text("AI-powered smart glasses built with Flutter, Gemini, and ESP32."),
                ],
              );
            },
          ),

          const Divider(height: 32),

          //Logout
          ListTile(
            leading: Icon(Icons.logout,
                color: themeProvider.isDarkMode ? Colors.redAccent : Colors.red),
            title: Text(
              "Logout",
              style: AppFonts.body.copyWith(
                color: themeProvider.isDarkMode ? Colors.redAccent : Colors.red,
              ),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
