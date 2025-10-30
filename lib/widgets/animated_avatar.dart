import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// A widget that displays an animated avatar using a Lottie file.
///
/// This avatar can dynamically change its appearance based on the provided
/// parameters, such as looking left or right and wearing glasses. It uses
/// [LottieDelegates] to control the opacity of different layers within the
/// Lottie animation.
class AnimatedAvatar extends StatelessWidget {
  /// A boolean that determines if the avatar should be looking to the left.
  final bool isLookingLeft;
  /// A boolean that determines if the avatar should be wearing glasses.
  final bool isWearingGlasses;

  /// Creates an [AnimatedAvatar].
  ///
  /// [isLookingLeft] and [isWearingGlasses] are required.
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
