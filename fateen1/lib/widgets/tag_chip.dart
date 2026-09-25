import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';

/// Removable pill/chip for a selected allergy or chronic disease.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          InkResponse(
            onTap: onRemove,
            radius: 20,
            child: const Icon(Icons.remove_circle, color: AppColors.primary),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(label, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
