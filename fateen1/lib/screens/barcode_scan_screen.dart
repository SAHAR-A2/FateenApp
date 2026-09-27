import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/scan_action_button.dart';
import '../logic/gtin.dart';
import '../services/product_check_service.dart';

/// Product barcodes FATEEN can look up (retail EAN/UPC families).
const _productFormats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
];

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final ImagePicker picker = ImagePicker();
  final MobileScannerController scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: _productFormats,
  );
  // نستخدم بايتات الصورة (Uint8List) بدل dart:io File لأن File غير مدعومة
  // إطلاقًا على منصة الويب (كروم) وتتسبب بتعطّل الشاشة عند اختيار صورة.
  Uint8List? selectedImageBytes;
  bool isAnalyzing = false;
  bool isLiveScanning = false;

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  Future<void> _startLiveScan() async {
    setState(() {
      selectedImageBytes = null;
      isLiveScanning = true;
    });
    try {
      await scannerController.start();
    } catch (_) {
      // The MobileScanner errorBuilder shows the reason in the frame.
    }
  }

  Future<void> _stopLiveScan() async {
    await scannerController.stop();
    if (mounted) setState(() => isLiveScanning = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isAnalyzing) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) return;

    HapticFeedback.mediumImpact();
    await _stopLiveScan();
    await _checkBarcode(value);
  }

  Future<void> _checkBarcode(String barcode) async {
    if (!mounted) return;
    setState(() => isAnalyzing = true);
    await checkAndOpenResult(context, barcode);
    if (mounted) setState(() => isAnalyzing = false);
  }

  Future<void> _pickImage() async {
    if (isLiveScanning) await _stopLiveScan();
    if (!mounted) return;

    XFile? image;
    try {
      image = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذر فتح الألبوم — تأكد من منح إذن الوصول للصور.')),
      );
      return;
    }
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => selectedImageBytes = bytes);

    if (kIsWeb) {
      // mobile_scanner لا يدعم قراءة الباركود من مسار صورة على الويب.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'قراءة الباركود من صورة غير مدعومة على المتصفح؛ استخدم المسح المباشر أو أدخل الرقم'),
        ),
      );
      return;
    }

    setState(() => isAnalyzing = true);
    BarcodeCapture? capture;
    try {
      capture = await scannerController.analyzeImage(image.path);
    } catch (_) {
      capture = null;
    }
    if (!mounted) return;
    setState(() => isAnalyzing = false);

    final value = capture?.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لم يُتعرف على باركود بالصورة، جرب صورة أوضح وأقرب')),
      );
      return;
    }
    await _checkBarcode(value);
  }

  Future<void> _enterManually() async {
    if (isLiveScanning) await _stopLiveScan();
    if (!mounted) return;
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => const _ManualBarcodeDialog(),
    );
    if (barcode != null && barcode.isNotEmpty) await _checkBarcode(barcode);
  }

  Widget _buildFrameContent() {
    if (isLiveScanning) {
      return MobileScanner(
        controller: scannerController,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) => Container(
          color: AppColors.border,
          padding: const EdgeInsets.all(AppSpacing.md),
          alignment: Alignment.center,
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'لا يوجد إذن لاستخدام الكاميرا — فعّله من إعدادات الجهاز'
                : 'تعذّر تشغيل الكاميرا؛ استخدم الألبوم أو أدخل رقم الباركود',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ),
      );
    }
    if (selectedImageBytes != null) {
      return Image.memory(selectedImageBytes!,
          width: double.infinity, height: double.infinity, fit: BoxFit.cover);
    }
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.border,
      child: const Icon(Icons.qr_code_scanner_rounded,
          size: 72, color: AppColors.textSecondary),
    );
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
                      Positioned.fill(child: _buildFrameContent()),
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
                            child: Text('جاري الفحص..',
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
                title: isLiveScanning ? 'إيقاف الكاميرا' : 'امسح بالكاميرا',
                icon: isLiveScanning
                    ? Icons.stop_circle_outlined
                    : Icons.camera_alt_outlined,
                selected: true,
                onTap: () {
                  if (isAnalyzing) return;
                  isLiveScanning ? _stopLiveScan() : _startLiveScan();
                },
              ),
              const SizedBox(height: AppSpacing.smMd),
              ScanActionButton(
                title: 'اختر صورة من الألبوم',
                icon: Icons.photo_library_outlined,
                selected: false,
                onTap: () {
                  if (!isAnalyzing) _pickImage();
                },
              ),
              const SizedBox(height: AppSpacing.smMd),
              TextButton.icon(
                onPressed: isAnalyzing ? null : _enterManually,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('أدخل رقم الباركود يدويًا'),
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

class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (![8, 12, 13, 14].contains(value.length)) {
      setState(() => _error = 'الباركود يتكون من 8 أو 12 أو 13 أو 14 رقمًا');
      return;
    }
    if (!hasValidGtinCheckDigit(value)) {
      setState(() => _error = 'رقم الباركود غير صحيح، تحقق من الأرقام');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('رقم الباركود'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 14,
        decoration: InputDecoration(
          hintText: 'مثال: 6281007031585',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('فحص')),
      ],
    );
  }
}
