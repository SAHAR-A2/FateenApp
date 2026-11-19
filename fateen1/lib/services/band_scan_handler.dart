import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'ble_service.dart';
import 'product_check_service.dart';

/// الجسر بين السوارة والفحص الصحي.
/// يستمع لأي باركود يصل من السوارة عبر البلوتوث ويمرّره على نفس مسار الفحص
/// المستخدم في باقي التطبيق ([ProductCheckService]: بيانات المنتج والقرار
/// من الـ backend)، ثم يرسل النتيجة للسوارة لتضيء اللمبة المناسبة ويفتح
/// شاشة النتيجة. الفرق الوحيد أن الباركود يأتي من السوارة لا من الكاميرا.
class BandScanHandler {
  BandScanHandler._internal();
  static final BandScanHandler instance = BandScanHandler._internal();

  bool _isListening = false;

  /// يُنادى مرة واحدة فقط وقت تشغيل التطبيق (من main.dart).
  void start(GlobalKey<NavigatorState> navigatorKey) {
    if (_isListening) return;
    _isListening = true;

    BleService.instance.barcodeStream.listen((barcode) async {
      await _handleBandBarcode(barcode, navigatorKey);
    });
  }

  Future<void> _handleBandBarcode(
    String barcode,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    debugPrint('[BandScanHandler] barcode from band: $barcode');

    // المستخدم غير مسجّل دخول: نتجاهل بصمت (لا شاشة نتيجة فوق شاشة الدخول).
    if (AuthService().getCurrentUserId() == null) return;

    try {
      final outcome = await ProductCheckService().check(barcode);

      // نرسل النتيجة للسوارة لتضيء اللمبة الصحيحة.
      await BleService.instance.sendResult(outcome.result.status);

      _showResultIfPossible(navigatorKey, {
        'status': outcome.result.status.uiKey,
        'message': outcome.result.reason,
        'productName': outcome.product.name,
        'barcode': outcome.product.barcode,
        'product': outcome.product,
        'source': 'band',
      });
    } on ProductCheckException catch (e) {
      // منتج غير موجود أو تعذّر الفحص: نعرض السبب، ولا نغيّر لمبات السوارة.
      _showResultIfPossible(navigatorKey, {
        'status': 'unknown',
        'message': e.message,
        'source': 'band',
      });
    } catch (e) {
      debugPrint('[BandScanHandler] unexpected error: $e');
    }
  }

  void _showResultIfPossible(
    GlobalKey<NavigatorState> navigatorKey,
    Map<String, dynamic> arguments,
  ) {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('[BandScanHandler] navigatorKey has no state; result not shown');
      return;
    }
    state.pushNamed('/result', arguments: arguments);
  }
}
