import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';

/// A question with a row of selectable pill choices underneath.
/// Used for the allergy-severity questions on Register / Edit Profile.
class ChoiceQuestion extends StatelessWidget {
  const ChoiceQuestion({
    super.key,
    required this.question,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final String question;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          question,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((option) {
            final selected = option == selectedValue;
            return GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smMd, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
