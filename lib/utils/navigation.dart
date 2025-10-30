import 'package:flutter/material.dart';

/// A utility function for navigating to a new page with a slide transition.
///
/// This function pushes a new route to the navigator using a [PageRouteBuilder]
/// to create a custom slide animation from right to left.
///
/// [context] The [BuildContext] from which to initiate the navigation.
/// [page] The widget for the new page to be displayed.
void navigateWithSlide(BuildContext context, Widget page) {
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0); // Slide from right
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOut));
        final offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    ),
  );
}
