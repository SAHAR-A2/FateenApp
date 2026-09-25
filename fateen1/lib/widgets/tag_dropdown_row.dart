import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';

/// Circular "+" add button followed by a dropdown — used for picking
/// an allergy or a chronic disease before adding it as a [TagChip].
class TagDropdownRow extends StatelessWidget {
  const TagDropdownRow({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onAdd,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.textField),
              boxShadow: AppShadows.card,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                alignment: AlignmentDirectional.center,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                hint: Text(' اختر..', textAlign: TextAlign.center, style: AppTextStyles.body),
                items: options
                    .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o, textAlign: TextAlign.center, style: AppTextStyles.body),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
