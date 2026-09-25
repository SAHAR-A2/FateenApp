import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// The single reusable text field used across Login, Register, and Search.
class FateenTextField extends StatelessWidget {
  const FateenTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.obscureText = false,
    this.onChanged,
    this.prefixIcon,
  });

  final TextEditingController? controller;
  final String hintText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      textAlign: TextAlign.right,
      style: AppTextStyles.body,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        suffixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.primary, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}
