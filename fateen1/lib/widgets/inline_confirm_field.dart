import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'fateen_text_field.dart';

/// A circular checkmark button + text field, used whenever a selection
/// needs a free-text follow-up (e.g. "الفواكه" allergy → specify which
/// fruit).
class InlineConfirmField extends StatelessWidget {
  const InlineConfirmField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onConfirm,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onConfirm,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.check_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: FateenTextField(controller: controller, hintText: hintText)),
      ],
    );
  }
}
