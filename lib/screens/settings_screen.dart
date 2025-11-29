import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'chat_home_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/user_avatar.dart';
// import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isFirstTime = true;
  String _welcomeMessage = "Welcome";
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Use readAsBytes for cross-platform compatibility (Web & Mobile)
      final imageBytes = await pickedFile.readAsBytes();
      
      try {
        await authProvider.uploadProfileImage(imageBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    bool? firstTime = prefs.getBool('first_time_settings');

    if (firstTime == null || firstTime == true) {
      setState(() {
        _isFirstTime = true;
        _welcomeMessage = "Welcome";
      });
      await prefs.setBool('first_time_settings', false);
    } else {
      setState(() {
        _isFirstTime = false;
        _welcomeMessage = "Welcome back";
      });
    }
  }

  void _goToChatHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
      (route) => false,
    );
  }

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final TextEditingController nameController =
        TextEditingController(text: user?.displayName ?? "");

    showDialog(
      context: context,
      builder: (ctx) {
        final themeProvider = Provider.of<ThemeProvider>(ctx);
        final isDark = themeProvider.isDarkMode;
        
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: Text(
            "Edit Profile",
            style: AppFonts.heading.copyWith(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: TextField(
            controller: nameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: "Display Name",
              labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: isDark ? Colors.grey : Colors.black54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: isDark ? AppColors.neonBlue : Colors.blue),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue,
              ),
              onPressed: () async {
                await authProvider.updateProfile(displayName: nameController.text);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final themeProvider = Provider.of<ThemeProvider>(ctx);
        final isDark = themeProvider.isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: Text("Change Password", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: "New Password",
              labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey : Colors.black54)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue),
              onPressed: () async {
                try {
                  await Provider.of<AuthProvider>(context, listen: false).changePassword(passwordController.text);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully")));
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e. You may need to re-login.")));
                  }
                }
              },
              child: const Text("Update", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final themeProvider = Provider.of<ThemeProvider>(ctx);
        final isDark = themeProvider.isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: Text("Delete Account", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Text(
            "Are you sure you want to delete your account? This action cannot be undone.",
            style: TextStyle(color: isDark ? Colors.grey : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await Provider.of<AuthProvider>(context, listen: false).deleteAccount();
                  if (mounted) {
                    Navigator.pop(ctx); // Close dialog
                    // Navigation to AuthScreen is handled by AuthProvider listener or we force it here
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e. You may need to re-login.")));
                  }
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.background : Colors.white,
        elevation: 0,
        title: Text(
          'Settings',
          style: AppFonts.heading.copyWith(
            color: isDark ? AppColors.neonBlue : Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => _goToChatHome(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 👤 Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Selector<AuthProvider, String?>(
                        selector: (_, auth) => auth.user?.photoURL,
                        builder: (context, photoURL, child) {
                          return CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.neonBlue,
                            backgroundImage: photoURL != null
                                ? NetworkImage(photoURL)
                                : null,
                            child: _isUploading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : (photoURL == null
                                    ? Selector<AuthProvider, String?>(
                                        selector: (_, auth) => auth.user?.displayName,
                                        builder: (context, displayName, _) {
                                          return Text(
                                            displayName?.isNotEmpty == true
                                                ? displayName![0].toUpperCase()
                                                : "U",
                                            style: const TextStyle(
                                              fontSize: 32,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      )
                                    : null),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "$_welcomeMessage, ${user?.displayName ?? 'User'}!",
                  style: AppFonts.heading.copyWith(
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  user?.email ?? "",
                  style: AppFonts.body.copyWith(
                    color: isDark ? Colors.grey : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileDialog(context),
                  icon: Icon(Icons.edit, size: 18, color: AppColors.neonBlue),
                  label: Text(
                    "Edit Profile",
                    style: TextStyle(color: AppColors.neonBlue),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.neonBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 🔁 Theme toggle
          ListTile(
            leading: Icon(Icons.dark_mode,
                color: isDark ? Colors.white : Colors.black),
            title: Text(
              "Dark Mode",
              style: AppFonts.body.copyWith(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            trailing: Switch(
              value: isDark,
              onChanged: (val) => themeProvider.toggleTheme(val),
              activeColor: AppColors.neonBlue,
            ),
          ),

          // ℹ️ About
          ListTile(
            leading: Icon(Icons.info_outline,
                color: isDark ? Colors.white : Colors.black),
            title: Text(
              "About OptiAI",
              style: AppFonts.body.copyWith(
                color: isDark ? Colors.white : Colors.black,
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

          // 🔐 Account Actions
          ListTile(
            leading: Icon(Icons.lock_outline,
                color: isDark ? Colors.white : Colors.black),
            title: Text(
              "Change Password",
              style: AppFonts.body.copyWith(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            onTap: () => _showChangePasswordDialog(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever,
                color: isDark ? Colors.redAccent : Colors.red),
            title: Text(
              "Delete Account",
              style: AppFonts.body.copyWith(
                color: isDark ? Colors.redAccent : Colors.red,
              ),
            ),
            onTap: () => _showDeleteAccountDialog(context),
          ),

          //Logout
          ListTile(
            leading: Icon(Icons.logout,
                color: isDark ? Colors.redAccent : Colors.red),
            title: Text(
              "Logout",
              style: AppFonts.body.copyWith(
                color: isDark ? Colors.redAccent : Colors.red,
              ),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
