import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// Reusable product row used in Search and Favorites screens.
class ProductListTile extends StatelessWidget {
  const ProductListTile({
    super.key,
    required this.name,
    required this.imagePath,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final String name;
  final String imagePath;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  // ============ يقرر أي نوع صورة نعرض: رابط شبكة أو أصل محلي ============
  Widget _buildImage() {
    final placeholder = Container(
      width: 58,
      height: 50,
      color: AppColors.border,
      child: const Icon(Icons.inventory_2_outlined,
          color: AppColors.textSecondary, size: 20),
    );

    if (imagePath.isEmpty) return placeholder;

    final isNetworkImage = imagePath.startsWith('http');

    if (isNetworkImage) {
      return Image.network(
        imagePath,
        width: 58,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: 58,
            height: 50,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      imagePath,
      width: 58,
      height: 50,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: _buildImage(),
              ),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FavoriteIcon(isFavorite: isFavorite, onTap: onFavoriteTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteIcon extends StatelessWidget {
  const _FavoriteIcon({required this.isFavorite, required this.onTap});
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFavorite),
          color: isFavorite ? AppColors.favoriteRed : AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}
