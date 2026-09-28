import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = '';
  bool _isLoading = true;

  final bool _isConnectingBracelet = false;
  final bool _isBraceletConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final userId = AuthService().getCurrentUserId();
      final user = await FirestoreService().getUserProfile(userId!);
      if (mounted) {
        setState(() {
          _username = user!.username;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // There is no Bluetooth pairing yet, and the dish-photo estimate is not
  // served by the public API. Say so instead of simulating a connection or
  // opening a screen that can only fail.
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature قريبًا')),
    );
  }

  Future<void> _connectBracelet() async => _showComingSoon('ربط السوار');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text(
                _isLoading ? 'مرحبا بك' : 'مرحبا بك $_username',
                textAlign: TextAlign.center,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'معك في كل خطوة نحو غذاء أكثر أماناً',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xl),
              _MainButton(
                title: 'ابحث عن منتج',
                icon: Icons.search_rounded,
                onTap: () => Navigator.pushNamed(context, '/search'),
              ),
              const SizedBox(height: AppSpacing.smMd),
              Row(
                children: [
                  Expanded(
                    child: _SmallButton(
                      title: 'صور الطبق',
                      icon: Icons.restaurant_menu_rounded,
                      onTap: () => _showComingSoon('تصوير الطبق'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smMd),
                  Expanded(
                    child: _SmallButton(
                      title: 'صور الباركود',
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, '/barcode-scan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smMd),
              _BraceletConnectButton(
                isConnecting: _isConnectingBracelet,
                isConnected: _isBraceletConnected,
                onTap: _connectBracelet,
              ),
              const Spacer(),
              const AppBottomNavBar(selectedIndex: 0),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton(
      {required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: AppSpacing.smMd),
                Text(title, style: AppTextStyles.button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BraceletConnectButton extends StatelessWidget {
  const _BraceletConnectButton({
    required this.isConnecting,
    required this.isConnected,
    required this.onTap,
  });

  final bool isConnecting;
  final bool isConnected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title = isConnecting
        ? 'جاري البحث عن السوار..'
        : isConnected
            ? 'تم الاتصال بالسوار'
            : 'الاتصال بالسوار';

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: isConnecting ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isConnecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                else
                  Icon(
                    isConnected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                const SizedBox(width: AppSpacing.smMd),
                Text(
                  title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(
      {required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: SizedBox(
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
