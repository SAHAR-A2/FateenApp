import 'package:flutter/material.dart';
import '../core/theme/app_text_styles.dart';

/// Right-aligned section heading (no icon — kept intentionally plain).
/// Used above the allergies / chronic diseases pickers.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(title, style: AppTextStyles.subtitle),
    );
  }
}
