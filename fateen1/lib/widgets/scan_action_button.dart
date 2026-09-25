import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';

/// The "افتح الكاميرا" / "افتح الألبوم" pill buttons shared by the
/// barcode-scan and dish-scan screens.
class ScanActionButton extends StatelessWidget {
  const ScanActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: AppShadows.card,
          ),
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : AppColors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
