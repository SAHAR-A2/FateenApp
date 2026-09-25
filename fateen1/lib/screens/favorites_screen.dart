import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/product_list_title.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../services/fateen_api_service.dart';
import '../models/product_model.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _favoriteProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final userId = AuthService().getCurrentUserId();
      final barcodes = await FavoritesService().getFavorites(userId!);

      final apiService = FateenApiService();
      final List<Product> products = [];
      for (String barcode in barcodes) {
        final product = await apiService.getProductByBarcode(barcode);
        if (product != null) products.add(product);
      }

      if (mounted) {
        setState(() {
          _favoriteProducts = products;
          _isLoading = false;
        });
      }
    } catch (errorMessage) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  Future<void> _removeFavorite(Product product) async {
    try {
      final userId = AuthService().getCurrentUserId();
      await FavoritesService().removeFromFavorites(userId!, product.barcode);
      setState(() => _favoriteProducts.remove(product));
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: AppSpacing.sm),
              Text('قائمة المفضلة..', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _favoriteProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_border_rounded,
                                    size: 44, color: AppColors.textSecondary),
                                const SizedBox(height: AppSpacing.sm),
                                Text('لا توجد منتجات في المفضلة',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _favoriteProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.listItemGap),
                            itemBuilder: (context, index) {
                              final product = _favoriteProducts[index];
                              return ProductListTile(
                                name: product.name,
                                imagePath: product.imageUrl,
                                selected: false,
                                isFavorite: true,
                                onTap: () {},
                                onFavoriteTap: () => _removeFavorite(product),
                              );
                            },
                          ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppBottomNavBar(selectedIndex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
