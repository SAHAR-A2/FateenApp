import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../widgets/circle_icon_button.dart';
import '../models/store_model.dart';
import '../main.dart';

/// صفحة منتجات متجر واحد. تُفتح من صفحة "المتاجر" عند الضغط على
/// متجر معيّن، وتعرض شريط بحث أعلى الصفحة وقائمة منتجات ذلك المتجر
/// فقط (بنفس ثيم قائمة المفضلة).
class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.store});
  final Store store;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StoreProduct> get _filteredProducts {
    if (_query.trim().isEmpty) return widget.store.products;
    return widget.store.products
        .where((p) => '${p.name} ${p.nameEn}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase()))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const BackCircleButton(),
                  const Spacer(),
                  Text(
                      FateenApp.locale.value.languageCode == 'ar'
                          ? widget.store.name
                          : 'Al Hatab Foods',
                      style: AppTextStyles.subtitle),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.textField),
                  boxShadow: AppShadows.card,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'ابحث داخل المتجر / Search this store',
                    hintStyle: TextStyle(color: Colors.white70, fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 44, color: AppColors.textSecondary),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                                FateenApp.locale.value.languageCode == 'ar'
                                    ? 'لا توجد منتجات بهذا المتجر بعد'
                                    : 'No matching products',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.listItemGap),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _StoreProductTile(product: product);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreProductTile extends StatelessWidget {
  const _StoreProductTile({required this.product});
  final StoreProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: product.imageUrl.isEmpty
                    ? Container(
                        width: 76,
                        height: 76,
                        color: AppColors.border,
                        child: const Icon(Icons.inventory_2_outlined))
                    : Image.network(product.imageUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined))),
            const SizedBox(width: AppSpacing.smMd),
            Expanded(
                child: Text(
                    FateenApp.locale.value.languageCode == 'ar'
                        ? product.name
                        : (product.nameEn.isEmpty
                            ? product.name
                            : product.nameEn),
                    style: AppTextStyles.bodyMedium)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          if (product.barcode != null)
            Text(
                '${FateenApp.locale.value.languageCode == 'ar' ? 'الباركود' : 'Barcode'}: ${product.barcode}',
                style: AppTextStyles.caption),
          if (product.details != null)
            Text(product.details!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          if (product.ingredients != null)
            Text(
                '${FateenApp.locale.value.languageCode == 'ar' ? 'المكونات' : 'Ingredients'}: ${product.ingredients}',
                style: AppTextStyles.caption),
          if (product.sourceUrl != null)
            SelectableText(
                '${FateenApp.locale.value.languageCode == 'ar' ? 'المصدر الرسمي' : 'Official source'}: ${product.sourceUrl}',
                style: AppTextStyles.caption.copyWith(color: Colors.blue)),
        ],
      ),
    );
  }
}
