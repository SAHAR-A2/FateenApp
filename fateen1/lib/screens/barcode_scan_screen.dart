import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/scan_action_button.dart';
import '../services/fateen_api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/api_client.dart';
import '../models/compatibility_result_model.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final ImagePicker picker = ImagePicker();
  final MobileScannerController scannerController = MobileScannerController();
  // نستخدم بايتات الصورة (Uint8List) بدل dart:io File لأن File غير مدعومة
  // إطلاقًا على منصة الويب (كروم) وتتسبب بتعطّل الشاشة عند اختيار صورة.
  Uint8List? selectedImageBytes;
  bool isAnalyzing = false;

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

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

    if (kIsWeb) {
      // mobile_scanner لا يدعم قراءة الباركود من مسار صورة على الويب.
      setState(() => isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'مسح الباركود من صورة غير مدعوم حاليًا على المتصفح، يرجى استخدام التطبيق على الجوال'),
        ),
      );
      return;
    }

    await _analyzeAndCheckHealth(image.path, source);

    if (mounted) setState(() => isAnalyzing = false);
  }

  Future<void> _analyzeAndCheckHealth(
      String imagePath, ImageSource source) async {
    try {
      final BarcodeCapture? capture =
          await scannerController.analyzeImage(imagePath);

      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('لم يُتعرف على باركود بالصورة، جرب صورة أوضح وأقرب')),
        );
        return;
      }

      final String? barcodeValue = capture.barcodes.first.rawValue;
      if (barcodeValue == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تعذّرت قراءة رقم الباركود، حاول مرة أخرى')),
        );
        return;
      }

      final apiService = FateenApiService();
      final product = await apiService.getProductByBarcode(barcodeValue);

      if (product == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا المنتج غير موجود بقاعدة البيانات')),
        );
        return;
      }

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
        'source': source == ImageSource.camera ? 'camera' : 'album',
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
                  Text('مسح الباركود', style: AppTextStyles.subtitle),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: 260,
                width: double.infinity,
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
                          child: const Icon(Icons.qr_code_scanner_rounded,
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
