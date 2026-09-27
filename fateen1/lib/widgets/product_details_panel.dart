import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';

/// Product facts behind a compatibility result: allergens, ingredients and
/// nutrition exactly as FateenDB holds them. Missing sections are stated
/// as missing, never hidden or filled in.
class ProductDetailsPanel extends StatelessWidget {
  const ProductDetailsPanel({super.key, required this.product});

  final Product product;

  static const _nutritionLabels = {
    'ENERGY': 'الطاقة',
    'PROTEIN': 'البروتين',
    'CARBOHYDRATE': 'الكربوهيدرات',
    'SUGAR': 'السكريات',
    'TOTAL_FAT': 'الدهون الكلية',
    'SATURATED_FAT': 'الدهون المشبعة',
    'TRANS_FAT': 'الدهون المتحولة',
    'FIBER': 'الألياف',
    'SODIUM': 'الصوديوم',
    'SALT': 'الملح',
    'CHOLESTEROL': 'الكوليسترول',
  };

  static const _unitLabels = {
    'G': 'غ',
    'MG': 'ملغ',
    'KG': 'كغ',
    'ML': 'مل',
    'L': 'لتر',
    'KCAL': 'سعرة',
    'KJ': 'كيلوجول',
  };

  static const _basisLabels = {
    'PER_100G': 'لكل 100 غ',
    'PER_100ML': 'لكل 100 مل',
    'PER_SERVING': 'لكل حصة',
    'PER_PACKAGE': 'لكل عبوة',
  };

  static String nutritionLabel(String code) =>
      _nutritionLabels[code.toUpperCase()] ?? code;

  static String unitLabel(String? unit) =>
      unit == null ? '' : (_unitLabels[unit.toUpperCase()] ?? unit);

  static String? basisLabel(String? basis) =>
      basis == null ? null : (_basisLabels[basis.toUpperCase()] ?? basis);

  static String formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final contains = product.allergens
        .where((a) => a.relationshipType != 'MAY_CONTAIN_ALLERGEN')
        .toList();
    final mayContain = product.allergens
        .where((a) => a.relationshipType == 'MAY_CONTAIN_ALLERGEN')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'مسببات الحساسية',
          icon: Icons.warning_amber_rounded,
          child: product.allergens.isEmpty
              ? const _Missing('لا تتوفر بيانات عن مسببات الحساسية لهذا المنتج')
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final a in contains)
                      _Tag(label: 'يحتوي: ${a.name}', color: AppColors.danger),
                    for (final a in mayContain)
                      _Tag(label: 'قد يحتوي: ${a.name}', color: AppColors.warning),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.smMd),
        _Section(
          title: 'المكونات',
          icon: Icons.list_alt_rounded,
          child: product.ingredients.isEmpty
              ? const _Missing('لا تتوفر قائمة المكونات لهذا المنتج')
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final i in product.ingredients)
                      _Tag(label: i.name, color: AppColors.primaryDark),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.smMd),
        _Section(
          title: 'القيم الغذائية',
          icon: Icons.bar_chart_rounded,
          child: product.nutrition.isEmpty
              ? const _Missing('لا تتوفر القيم الغذائية لهذا المنتج')
              : Column(
                  children: [
                    for (final n in product.nutrition) _NutritionRow(value: n),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'المعلومات من قاعدة بيانات فطين وقد تكون ناقصة؛ راجع ملصق المنتج دائمًا.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTextStyles.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smMd, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow({required this.value});
  final FateenNutritionValue value;

  @override
  Widget build(BuildContext context) {
    final basis = ProductDetailsPanel.basisLabel(value.measurementBasis);
    final amount =
        '${ProductDetailsPanel.formatAmount(value.amountValue)} ${ProductDetailsPanel.unitLabel(value.unit)}'
            .trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ProductDetailsPanel.nutritionLabel(value.nutritionType),
              style: AppTextStyles.body,
            ),
          ),
          Text(amount, style: AppTextStyles.bodyMedium),
          if (basis != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              basis,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
