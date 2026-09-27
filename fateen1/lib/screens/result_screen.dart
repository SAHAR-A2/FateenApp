import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/product_list_title.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/fateen_api_service.dart';
import '../services/favorites_service.dart';
import '../services/product_check_service.dart';
import '../widgets/product_details_panel.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _argsHandled = false;

  bool _isLoadingAlternatives = false;
  List<Product> _alternatives = [];
  Set<String> _favoriteBarcodes = {};

  _ResultData _getResultData(String status, String? customMessage) {
    switch (status) {
      case 'danger':
        return _ResultData(
          color: AppColors.danger,
          title: 'تحذير',
          message: customMessage ?? 'هذا المنتج لا يتناسب مع حالتك الصحية',
          icon: Icons.warning_amber_rounded,
        );
      case 'warning':
        return _ResultData(
          color: AppColors.warning,
          title: 'انتبه',
          message:
              customMessage ?? 'هذا المنتج لا يتناسب تمامًا مع حالتك الصحية',
          icon: Icons.warning_amber_rounded,
        );
      case 'safe':
        return _ResultData(
          color: AppColors.success,
          title: 'آمن',
          message: customMessage ?? 'هذا المنتج يتناسب مع حالتك الصحية',
          icon: Icons.check_rounded,
        );
      case 'unknown':
      default:
        return _ResultData(
          color: AppColors.info,
          title: 'معلومات ناقصة',
          message: customMessage ?? 'لا توجد معلومات كافية عن هذا المنتج',
          icon: Icons.info_outline_rounded,
        );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsHandled) return;
    _argsHandled = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map ? args : const {};
    final String status = data['status']?.toString() ?? 'unknown';
    final String? excludeBarcode = data['barcode']?.toString();

    // نطلب بدائل من الخادم فقط عندما يكون المنتج غير مناسب تمامًا
    // (أحمر/برتقالي) ولدينا الباركود الأصلي لإرساله إلى FATEEN backend.
    if ((status == 'danger' || status == 'warning') &&
        excludeBarcode != null &&
        excludeBarcode.trim().isNotEmpty) {
      _loadAlternatives(excludeBarcode);
    }
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final userId = AuthService().getCurrentUserId();
      final favorites = await FavoritesService().getFavorites(userId!);
      if (mounted) setState(() => _favoriteBarcodes = favorites.toSet());
    } catch (_) {}
  }

  Future<void> _loadAlternatives(String barcode) async {
    setState(() => _isLoadingAlternatives = true);
    try {
      final userId = AuthService().getCurrentUserId();
      if (userId == null) return;
      final user = await FirestoreService().getUserProfile(userId);
      if (user == null) return;

      // The FATEEN backend finds candidates and confirms each one SAFE
      // through the same CompatibilityService used everywhere else --
      // this screen does not search or filter anything itself anymore.
      final safeAlternatives = await FateenApiService().getAlternatives(
        barcode: barcode,
        user: user,
      );

      if (mounted) setState(() => _alternatives = safeAlternatives);
    } catch (_) {
      // The section then shows "no confirmed alternative"; never a guess.
    } finally {
      if (mounted) setState(() => _isLoadingAlternatives = false);
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    final userId = AuthService().getCurrentUserId();
    if (userId == null) return;
    final isCurrentlyFavorite = _favoriteBarcodes.contains(product.barcode);
    try {
      if (isCurrentlyFavorite) {
        await FavoritesService().removeFromFavorites(userId, product.barcode);
      } else {
        await FavoritesService().addToFavorites(userId, product.barcode);
      }
      if (!mounted) return;
      setState(() {
        if (isCurrentlyFavorite) {
          _favoriteBarcodes.remove(product.barcode);
        } else {
          _favoriteBarcodes.add(product.barcode);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحديث المفضلة، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _openAlternative(Product product) =>
      checkAndOpenResult(context, product.barcode, replace: true);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map ? args : const {};
    final String status = data['status']?.toString() ?? 'unknown';
    final String? message = data['message']?.toString();
    final Product? product = data['product'] is Product ? data['product'] as Product : null;
    final String? productName = data['productName']?.toString();
    final result = _getResultData(status, message);
    final bool showAlternatives = status == 'danger' || status == 'warning';

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
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.9, end: 1.0),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: _ResultCard(result: result, productName: productName),
                      ),
                      if (product != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ProductDetailsPanel(product: product),
                      ],
                      if (showAlternatives) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _AlternativesSection(
                          isLoading: _isLoadingAlternatives,
                          alternatives: _alternatives,
                          favoriteBarcodes: _favoriteBarcodes,
                          onTap: _openAlternative,
                          onFavoriteTap: _toggleFavorite,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppBottomNavBar(selectedIndex: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, this.productName});
  final _ResultData result;
  final String? productName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 230),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.elevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 10, color: result.color),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: result.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(result.icon, color: result.color, size: 32),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(result.title, style: AppTextStyles.resultTitle),
          if (productName != null && productName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                productName!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.smMd),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(result.message, textAlign: TextAlign.center, style: AppTextStyles.resultDescription),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _AlternativesSection extends StatelessWidget {
  const _AlternativesSection({
    required this.isLoading,
    required this.alternatives,
    required this.favoriteBarcodes,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final bool isLoading;
  final List<Product> alternatives;
  final Set<String> favoriteBarcodes;
  final ValueChanged<Product> onTap;
  final ValueChanged<Product> onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text('منتجات بديلة تناسب حالتك', style: AppTextStyles.subtitle),
          ],
        ),
        const SizedBox(height: AppSpacing.smMd),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (alternatives.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg, horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Text(
              'لم نجد حاليًا بديلاً مؤكدًا يناسب حالتك الصحية لهذا المنتج',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alternatives.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.listItemGap),
            itemBuilder: (context, index) {
              final product = alternatives[index];
              return ProductListTile(
                name: product.name,
                imagePath: product.imageUrl,
                selected: false,
                isFavorite: favoriteBarcodes.contains(product.barcode),
                onTap: () => onTap(product),
                onFavoriteTap: () => onFavoriteTap(product),
              );
            },
          ),
      ],
    );
  }
}

class _ResultData {
  const _ResultData({required this.color, required this.title, required this.message, required this.icon});
  final Color color;
  final String title;
  final String message;
  final IconData icon;
}
