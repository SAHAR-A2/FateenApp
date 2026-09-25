import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/product_list_title.dart';
import '../services/fateen_api_service.dart';
import '../services/api_client.dart';
import '../models/compatibility_result_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/favorites_service.dart';
import '../models/product_model.dart';
import '../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();

  List<Product> _results = [];
  Set<String> _favoriteBarcodes = {};
  bool _isSearching = false;
  bool _isAuthorized = false;
  String? _searchError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _isAuthorized = AuthService().getCurrentUserId() != null;
    if (!_isAuthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      });
    }
    _loadFavorites();
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final userId = AuthService().getCurrentUserId();
      final favorites = await FavoritesService().getFavorites(userId!);
      if (mounted) setState(() => _favoriteBarcodes = favorites.toSet());
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _performSearch(value));
  }

  Future<void> _searchCategory(String label) async {
    _debounce?.cancel();
    searchController.text = label;
    await _performSearch(label);
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final isArabic = FateenApp.locale.value.languageCode == 'ar';
      final products = await FateenApiService()
          .searchProducts(trimmed, language: isArabic ? 'ar' : 'en');
      if (!mounted) return;
      setState(() => _results = products);
    } on FateenApiException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.message);
    } catch (errorMessage) {
      if (!mounted) return;
      setState(() => _searchError = 'تعذر إكمال البحث، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _openResult(Product product) async {
    if (product.barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يتوفر باركود لهذا المنتج بعد لعرض نتيجة التوافق'),
        ),
      );
      return;
    }

    try {
      final apiService = FateenApiService();
      final userId = AuthService().getCurrentUserId();
      final user = await FirestoreService().getUserProfile(userId!);

      // The FATEEN backend -- not this screen -- decides the compatibility
      // result (SAFE/WARNING/DANGER/UNKNOWN/INSUFFICIENT_DATA).
      final result = await apiService.getCompatibility(
        barcode: product.barcode,
        user: user!,
      );

      if (!mounted) return;
      Navigator.pushNamed(context, '/result', arguments: {
        'status': result.status.uiKey,
        'message': result.reason,
        'productName': product.name,
        'barcode': product.barcode,
        'source': 'search',
      });
    } on FateenApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    final userId = AuthService().getCurrentUserId();
    final isCurrentlyFavorite = _favoriteBarcodes.contains(product.barcode);

    try {
      if (isCurrentlyFavorite) {
        await FavoritesService().removeFromFavorites(userId!, product.barcode);
        setState(() => _favoriteBarcodes.remove(product.barcode));
      } else {
        await FavoritesService().addToFavorites(userId!, product.barcode);
        setState(() => _favoriteBarcodes.add(product.barcode));
      }
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
                          ? 'البحث'
                          : 'Search',
                      style: AppTextStyles.subtitle),
                  const Spacer(),
                  TextButton(
                      onPressed: () {
                        FateenApp.locale.value = Locale(
                            FateenApp.locale.value.languageCode == 'ar'
                                ? 'en'
                                : 'ar');
                        if (searchController.text.trim().isNotEmpty)
                          _performSearch(searchController.text);
                      },
                      child: Text(FateenApp.locale.value.languageCode == 'ar'
                          ? 'EN'
                          : 'عربي')),
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
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: Colors.blueGrey),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'ابحث عن منتج / Search products',
                    hintStyle: TextStyle(color: Colors.blueGrey, fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.blueGrey, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                    FateenApp.locale.value.languageCode == 'ar'
                        ? 'فئات المنتجات'
                        : 'Product categories',
                    style: AppTextStyles.caption),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final label in const [
                    'حليب / Milk',
                    'خبز / Bread',
                    'مخبوزات / Bakery',
                    'عصير / Juice',
                    'ماء / Water',
                    'تسالي / Snacks',
                  ])
                    ActionChip(
                      label: Text(label.split(' / ').elementAt(
                          FateenApp.locale.value.languageCode == 'ar' ? 0 : 1)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _searchCategory(label
                          .split(' / ')
                          .elementAt(FateenApp.locale.value.languageCode == 'ar'
                              ? 0
                              : 1)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _isSearching
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'جارٍ جلب النتائج من قاعدة البيانات…',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchError != null
                        ? Center(
                            child: Text(
                              _searchError!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off_rounded,
                                        size: 40,
                                        color: AppColors.textSecondary),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                        FateenApp.locale.value.languageCode ==
                                                'ar'
                                            ? 'لا توجد نتائج'
                                            : 'No results',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                color:
                                                    AppColors.textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => const SizedBox(
                                    height: AppSpacing.listItemGap),
                                itemBuilder: (context, index) {
                                  final product = _results[index];
                                  return ProductListTile(
                                    name: product.name,
                                    imagePath: product.imageUrl,
                                    selected: false,
                                    isFavorite: _favoriteBarcodes
                                        .contains(product.barcode),
                                    onTap: () => _openResult(product),
                                    onFavoriteTap: () =>
                                        _toggleFavorite(product),
                                  );
                                },
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
