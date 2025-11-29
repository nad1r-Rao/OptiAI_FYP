import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({super.key, this.radius = 20, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, String?>(
      selector: (_, auth) => auth.user?.photoURL,
      builder: (context, photoURL, child) {
        return GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.neonGreen,
            backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
            child: photoURL == null
                ? Selector<AuthProvider, String?>(
                    selector: (_, auth) => auth.user?.displayName,
                    builder: (context, displayName, _) {
                      return Text(
                        displayName?.isNotEmpty == true
                            ? displayName![0].toUpperCase()
                            : "U",
                        style: TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.bold,
                          fontSize: radius,
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}
