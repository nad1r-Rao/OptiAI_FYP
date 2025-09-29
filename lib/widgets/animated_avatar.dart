import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedAvatar extends StatelessWidget {
  final bool isLookingLeft;
  final bool isWearingGlasses;

  const AnimatedAvatar({
    super.key,
    required this.isLookingLeft,
    required this.isWearingGlasses,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Lottie.asset(
        'assets/lottie/avatar.json',
        fit: BoxFit.contain,
        delegates: LottieDelegates(
          values: [
            // Suppose you have 2 eye layers in your Lottie:
            // 'eye L left' and 'eye L right' (same for right eye)
            ValueDelegate.opacity(
              ['eye L left'],
              value: isLookingLeft ? 100 : 0,
            ),
            ValueDelegate.opacity(
              ['eye L right'],
              value: isLookingLeft ? 0 : 100,
            ),
            ValueDelegate.opacity(
              ['eye R left'],
              value: isLookingLeft ? 100 : 0,
            ),
            ValueDelegate.opacity(
              ['eye R right'],
              value: isLookingLeft ? 0 : 100,
            ),

            // Glasses opacity
            ValueDelegate.opacity(
              ['glasses'],
              value: isWearingGlasses ? 100 : 0,
            ),
          ],
        ),
      ),
    );
  }
}
