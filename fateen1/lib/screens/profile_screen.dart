import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../core/theme/app_theme.dart';
import '../data/allergy_options.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().getCurrentUserId();
      final user = await FirestoreService().getUserProfile(userId!);
      if (mounted) setState(() => _user = user);
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAllergy(UserAllergy allergy) async {
    final userId = AuthService().getCurrentUserId();
    final updated = List<UserAllergy>.from(_user!.allergies)..remove(allergy);

    try {
      await FirestoreService().updateUserAllergies(userId!, updated);
      setState(() {
        _user = AppUser(
          id: _user!.id,
          username: _user!.username,
          allergies: updated,
          diseases: _user!.diseases,
        );
      });
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  Future<void> _removeDisease(UserDisease disease) async {
    final userId = AuthService().getCurrentUserId();
    final updated = List<UserDisease>.from(_user!.diseases)..remove(disease);

    try {
      await FirestoreService().updateUserDiseases(userId!, updated);
      setState(() {
        _user = AppUser(
          id: _user!.id,
          username: _user!.username,
          allergies: _user!.allergies,
          diseases: updated,
        );
      });
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allergies = _user!.allergies;
    final diseases = _user!.diseases;
    final totalItems = allergies.length + diseases.length;

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
              Text('الصفحة الشخصية', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.card,
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(Icons.person_rounded,
                    size: 60, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(_user!.username, style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/edit-profile');
                  if (mounted) _loadProfile();
                },
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.primary),
                label: Text('تعديل الملف الشخصي',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
              ),
              const SizedBox(height: AppSpacing.smMd),
              Expanded(
                child: totalItems == 0
                    ? Center(
                        child: Text('لا توجد بيانات مضافة',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      )
                    : ListView(
                        children: [
                          ...allergies.map((allergy) {
                            final label = allergyTagMap.entries
                                .firstWhere((e) => e.value == allergy.tag,
                                    orElse: () => const MapEntry('حساسية', ''))
                                .key;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _TagItem(
                                  label: label,
                                  onRemove: () => _removeAllergy(allergy)),
                            );
                          }),
                          ...diseases.map((disease) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _TagItem(
                                  label: disease.name,
                                  onRemove: () => _removeDisease(disease)),
                            );
                          }),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppBottomNavBar(selectedIndex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagItem extends StatelessWidget {
  const _TagItem({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.remove_rounded,
          onTap: onRemove,
          size: 44,
          iconSize: 22,
          background: AppColors.primary,
          iconColor: Colors.white,
        ),
        const SizedBox(width: AppSpacing.smMd),
        Expanded(
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.card,
            ),
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
        ),
      ],
    );
  }
}
