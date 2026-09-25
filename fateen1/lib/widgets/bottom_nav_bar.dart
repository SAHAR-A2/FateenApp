import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// The four-tab bottom navigation (Home / Favorites / Stores / Profile).
/// Navigates using named routes registered in main.dart.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.selectedIndex});

  final int selectedIndex;

  void _goTo(BuildContext context, int index) {
    if (index == selectedIndex) return;
    const routes = ['/home', '/favorites', '/stores', '/profile'];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'الرئيسية',
            selected: selectedIndex == 0,
            onTap: () => _goTo(context, 0),
          ),
          _NavItem(
            icon: Icons.favorite_border_rounded,
            activeIcon: Icons.favorite_rounded,
            label: 'المفضلة',
            selected: selectedIndex == 1,
            onTap: () => _goTo(context, 1),
          ),
          _NavItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: 'المتاجر',
            selected: selectedIndex == 2,
            onTap: () => _goTo(context, 2),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'حسابي',
            selected: selectedIndex == 3,
            onTap: () => _goTo(context, 3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? AppSpacing.md : AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
              size: 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
