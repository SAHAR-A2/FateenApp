import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../data/store_data.dart';
import '../models/store_model.dart';
import 'store_detail_screen.dart';

/// تبويب "المتاجر": شريط بحث أعلى الصفحة + قائمة متاجر بنفس ثيم
/// صفحة المفضلة. الميزة قريبًا — الهيكل جاهز بالكامل لأسماء المتاجر،
/// فقط يلزم تعبئة `lib/data/store_data.dart` بالمتاجر الحقيقية.
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Store> get _filteredStores {
    if (_query.trim().isEmpty) return stores;
    return stores
        .where((s) => s.name.contains(_query.trim()))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStores;

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
              Text('المتاجر', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
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
                    hintText: 'ابحث عن متجر',
                    hintStyle: TextStyle(color: Colors.white70, fontSize: 15),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_outlined,
                                size: 44, color: AppColors.textSecondary),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              stores.isEmpty
                                  ? 'قسم المتاجر قريبًا..'
                                  : 'لا يوجد متجر مطابق لبحثك',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.listItemGap),
                        itemBuilder: (context, index) {
                          final store = filtered[index];
                          return _StoreTile(
                            store: store,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoreDetailScreen(store: store),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppBottomNavBar(selectedIndex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.store, required this.onTap});
  final Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: 58,
                  height: 50,
                  color: AppColors.border,
                  child: const Icon(Icons.storefront_rounded,
                      color: AppColors.textSecondary, size: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Text(
                  store.name,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
