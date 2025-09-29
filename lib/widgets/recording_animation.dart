import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RecordingAnimation extends StatefulWidget {
  const RecordingAnimation({super.key});

  @override
  State<RecordingAnimation> createState() => _RecordingAnimationState();
}

class _RecordingAnimationState extends State<RecordingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true); // keeps expanding and shrinking

    _animation = Tween<double>(begin: 50, end: 70).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: _animation.value,
            height: _animation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonGreen.withOpacity(0.3),
              border: Border.all(
                color: AppColors.neonGreen,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 30,
            ),
          );
        },
      ),
    );
  }
}
