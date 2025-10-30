import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// A widget that displays a single chat message in a styled bubble.
///
/// The bubble's appearance, such as its alignment and border color, changes
/// depending on whether the message is from the user or the AI. It also
/// features a fade-in animation when it first appears.
class ChatBubble extends StatefulWidget {
  /// A boolean that is `true` if the message is from the user.
  final bool isUser;
  /// The text content of the message.
  final String message;

  /// Creates a [ChatBubble].
  const ChatBubble({super.key, required this.isUser, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

/// The state for the [ChatBubble].
///
/// Manages the [AnimationController] for the fade-in animation.
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
