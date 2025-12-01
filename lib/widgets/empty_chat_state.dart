import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

class EmptyChatState extends StatefulWidget {
  const EmptyChatState({super.key});

  @override
  State<EmptyChatState> createState() => _EmptyChatStateState();
}

class _EmptyChatStateState extends State<EmptyChatState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconOpacity;
  late Animation<Offset> _iconSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _chipsOpacity;
  late Animation<Offset> _chipsSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _iconSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    _chipsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );
    _chipsSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final displayName = user?.displayName?.split(' ').first ?? 'Friend';

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Visual Icon/Animation
            FadeTransition(
              opacity: _iconOpacity,
              child: SlideTransition(
                position: _iconSlide,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonBlue.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 60,
                    color: AppColors.neonBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 2. Greeting
            FadeTransition(
              opacity: _textOpacity,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  children: [
                    Text(
                      "Hello, $displayName!",
                      style: AppFonts.heading.copyWith(
                        fontSize: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "How can I help you today?",
                      style: AppFonts.body.copyWith(
                        fontSize: 16,
                        color: AppColors.softWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 3. Suggestion Chips
            FadeTransition(
              opacity: _chipsOpacity,
              child: SlideTransition(
                position: _chipsSlide,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _SuggestionChip(
                      icon: Icons.camera_alt_outlined,
                      label: "Analyze Image",
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null && context.mounted) {
                          final bytes = await picked.readAsBytes();
                          context.read<ChatProvider>().sendTextWithImageToGemini("Analyze this image", bytes);
                        }
                      },
                    ),
                    _SuggestionChip(
                      icon: Icons.mic_none_outlined,
                      label: "Voice Chat",
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Long press the mic button below!")),
                        );
                      },
                    ),
                    _SuggestionChip(
                      icon: Icons.lightbulb_outline,
                      label: "Explain Quantum Physics",
                      onTap: () {
                        context.read<ChatProvider>().sendText("Explain quantum physics in simple terms");
                      },
                    ),
                     _SuggestionChip(
                      icon: Icons.calendar_today,
                      label: "Schedule an Event",
                      onTap: () {
                        context.read<ChatProvider>().sendText("Schedule a meeting with Team tomorrow at 10am");
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.neonBlue),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppFonts.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
