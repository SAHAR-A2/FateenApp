import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Small circular icon button — used for back buttons, add/remove
/// buttons, and confirm buttons across the app.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 16,
    this.background = AppColors.card,
    this.iconColor = AppColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

/// The standard top-left back button used on every non-root screen.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}
