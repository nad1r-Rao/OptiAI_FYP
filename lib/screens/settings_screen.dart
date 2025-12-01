import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../providers/chat_provider.dart';
import '../services/ai_services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isFirstTime = true;
  String _welcomeMessage = "Welcome";
  bool _isUploading = false;

  // New Settings State
  String _aiPersonality = 'Friendly';
  double _voiceSpeed = 0.5;
  bool _autoCapture = true;
  bool _isCheckingConnection = false;

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // First time check
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

    // Load other settings
    setState(() {
      _aiPersonality = prefs.getString('ai_personality') ?? 'Friendly';
      _voiceSpeed = prefs.getDouble('voice_speed') ?? 0.5;
      _autoCapture = prefs.getBool('auto_capture') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isCheckingConnection = true);
    final aiService = Provider.of<ChatProvider>(context, listen: false).aiService;
    final isConnected = await aiService.checkEsp32Connection();
    
    if (mounted) {
      setState(() => _isCheckingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isConnected ? "Connected to Glasses!" : "Could not connect to Glasses."),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showFeedbackDialog(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    // Check if feedback already exists
    final feedbackDoc = await FirebaseFirestore.instance
        .collection('feedback')
        .doc(user.uid)
        .get();

    if (feedbackDoc.exists && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Feedback Already Sent"),
          content: const Text("You have already submitted your feedback. Thank you!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    final TextEditingController feedbackController = TextEditingController();
    int rating = 5;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              title: Text("Send Feedback", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Rate your experience:", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "Tell us what you think...",
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue),
                  onPressed: () async {
                    if (feedbackController.text.trim().isEmpty) return;
                    
                    try {
                      await FirebaseFirestore.instance.collection('feedback').doc(user.uid).set({
                        'userId': user.uid,
                        'userEmail': user.email,
                        'message': feedbackController.text.trim(),
                        'rating': rating,
                        'timestamp': FieldValue.serverTimestamp(),
                        'appVersion': '1.0.0',
                      });
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Feedback sent! Thank you.")),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error sending feedback: $e")),
                        );
                      }
                    }
                  },
                  child: const Text("Send", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
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

          const SizedBox(height: 24),

          // 🤖 AI Preferences
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "AI Preferences",
              style: AppFonts.body.copyWith(
                color: isDark ? AppColors.neonBlue : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.psychology, color: isDark ? Colors.white : Colors.black),
            title: Text("Personality", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: DropdownButton<String>(
              value: _aiPersonality,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              underline: Container(),
              items: ['Friendly', 'Professional', 'Concise'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() => _aiPersonality = newValue);
                  _saveSetting('ai_personality', newValue);
                }
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.speed, color: isDark ? Colors.white : Colors.black),
            title: Text("Voice Speed: ${_voiceSpeed}x", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Slider(
              value: _voiceSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              activeColor: AppColors.neonBlue,
              onChanged: (value) {
                setState(() => _voiceSpeed = value);
                _saveSetting('voice_speed', value);
                Provider.of<ChatProvider>(context, listen: false).setVoiceSpeed(value);
              },
            ),
          ),

          const Divider(height: 32),

          // 👓 Glasses Settings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Glasses Settings",
              style: AppFonts.body.copyWith(
                color: isDark ? AppColors.neonBlue : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            secondary: Icon(Icons.camera, color: isDark ? Colors.white : Colors.black),
            title: Text("Auto-Capture", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text("Take photos automatically on relevant queries", style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 12)),
            value: _autoCapture,
            activeColor: AppColors.neonBlue,
            onChanged: (val) {
              setState(() => _autoCapture = val);
              _saveSetting('auto_capture', val);
            },
          ),
          ListTile(
            leading: Icon(Icons.wifi_tethering, color: isDark ? Colors.white : Colors.black),
            title: Text("Check Connection", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: _isCheckingConnection
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : OutlinedButton(
                    onPressed: _testConnection,
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.neonBlue)),
                    child: Text("Ping", style: TextStyle(color: AppColors.neonBlue)),
                  ),
          ),

          const Divider(height: 32),

          // 🤝 Support
          ListTile(
            leading: Icon(Icons.feedback_outlined, color: isDark ? Colors.white : Colors.black),
            title: Text("Send Feedback", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () => _showFeedbackDialog(context),
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
