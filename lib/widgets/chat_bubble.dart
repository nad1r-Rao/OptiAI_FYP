import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class ChatBubble extends StatefulWidget {
  final bool isUser;
  final String message;

  const ChatBubble({super.key, required this.isUser, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Align(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: theme.cardColor, // Adapts to light/dark mode
            border: Border.all(
              color: widget.isUser
                  ? AppColors.neonGreen
                  : AppColors.neonPurple,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            widget.message,
            style: AppFonts.body.copyWith(
              color: theme.textTheme.bodyLarge?.color, // Theme-aware text
            ),
          ),
        ),
      ),
    );
  }
}
