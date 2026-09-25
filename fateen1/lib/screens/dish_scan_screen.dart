import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/scan_action_button.dart';
import '../services/ai_vision_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../logic/health_checker.dart';
import '../models/compatibility_result_model.dart';

class DishScanScreen extends StatefulWidget {
  const DishScanScreen({super.key});

  @override
  State<DishScanScreen> createState() => _DishScanScreenState();
}

class _DishScanScreenState extends State<DishScanScreen> {
  final ImagePicker picker = ImagePicker();
  // بايتات الصورة بدل dart:io File، لأن File غير مدعومة على الويب وتسبب
  // تعطّل الشاشة عند اختيار/تصوير صورة من كروم.
  Uint8List? selectedImageBytes;
  bool isAnalyzing = false;

  Future<void> _pickImage(ImageSource source) async {
    XFile? image;
    try {
      image = await picker.pickImage(source: source);
    } catch (e) {
      if (!mounted) return;
      final isCameraSource = source == ImageSource.camera;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCameraSource
                ? 'تعذر فتح الكاميرا — تأكد من منح إذن الكاميرا للتطبيق (من إعدادات الجهاز)، أو أن الجهاز/المحاكي يحتوي كاميرا فعلية.'
                : 'تعذر فتح الألبوم — تأكد من منح إذن الوصول للصور.',
          ),
        ),
      );
      return;
    }
    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;
    setState(() {
      selectedImageBytes = bytes;
      isAnalyzing = true;
    });

    await _analyzeAndCheckHealth(image, source);

    if (mounted) setState(() => isAnalyzing = false);
  }

  Future<void> _analyzeAndCheckHealth(XFile image, ImageSource source) async {
    try {
      final dish = await AiVisionService().analyzeDishImage(image);

      final userId = AuthService().getCurrentUserId();
      final user = await FirestoreService().getUserProfile(userId!);

      final result = HealthChecker().checkDishCompatibility(dish, user!);

      if (!mounted) return;

      Navigator.pushNamed(context, '/result', arguments: {
        'status': result.status.uiKey,
        'message': result.reason,
        'productName': dish.name,
        'source': source == ImageSource.camera ? 'camera' : 'album',
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
                  Text('صور الطبق', style: AppTextStyles.subtitle),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                height: 260,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  boxShadow: AppShadows.card,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl - 3),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (selectedImageBytes != null)
                        Image.memory(selectedImageBytes!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover)
                      else
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: AppColors.border,
                          child: const Icon(Icons.restaurant_rounded,
                              size: 72, color: AppColors.textSecondary),
                        ),
                      if (isAnalyzing) ...[
                        Container(color: Colors.black.withValues(alpha: 0.4)),
                        Positioned(
                          bottom: AppSpacing.lg,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text('جاري المسح..',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: Colors.white)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ScanActionButton(
                title: 'افتح الكاميرا',
                icon: Icons.camera_alt_outlined,
                selected: true,
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: AppSpacing.smMd),
              ScanActionButton(
                title: 'افتح الألبوم',
                icon: Icons.photo_library_outlined,
                selected: false,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const Spacer(),
              const AppBottomNavBar(selectedIndex: 0),
            ],
          ),
        ),
      ),
    );
  }
}
