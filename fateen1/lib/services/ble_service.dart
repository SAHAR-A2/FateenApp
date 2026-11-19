import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/compatibility_result_model.dart';

/// نفس الـ UUIDs لازم تكون مطابقة تمامًا لفيرم وير ESP32
class BleUuids {
  static final Guid serviceUuid =
      Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');

  // ESP32 يرسل رقم الباركود للتطبيق عبر هذي (Notify)
  static final Guid barcodeCharUuid =
      Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  // التطبيق يرسل النتيجة لـ ESP32 عبر هذي (Write)
  static final Guid resultCharUuid =
      Guid('beb5483f-36e1-4688-b7f5-ea07361b26a9');
}

enum BleConnectionStatus { disconnected, scanning, connecting, connected }

/// Singleton: نسخة واحدة بس بكل التطبيق، عشان أي شاشة تقدر توصل لنفس الاتصال
/// بدون ما تنشئ اتصال ثاني بالغلط
class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _barcodeChar;
  BluetoothCharacteristic? _resultChar;
  StreamSubscription<List<int>>? _barcodeCharSubscription;

  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _barcodeController = StreamController<String>.broadcast();

  Stream<BleConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get barcodeStream => _barcodeController.stream;

  BleConnectionStatus _currentStatus = BleConnectionStatus.disconnected;
  BleConnectionStatus get currentStatus => _currentStatus;

  void _updateStatus(BleConnectionStatus s) {
    _currentStatus = s;
    _statusController.add(s);
  }

  /// يبدأ البحث عن السوارة ويتصل بأول جهاز يلقاه
  Future<void> scanAndConnect({String deviceNamePrefix = 'HealthBand'}) async {
    _updateStatus(BleConnectionStatus.scanning);

    await FlutterBluePlus.startScan(
      withServices: [BleUuids.serviceUuid],
      timeout: const Duration(seconds: 10),
    );

    final subscription = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.platformName.startsWith(deviceNamePrefix) ||
            r.advertisementData.serviceUuids.contains(BleUuids.serviceUuid)) {
          await FlutterBluePlus.stopScan();
          await _connect(r.device);
          break;
        }
      }
    });

    Future.delayed(const Duration(seconds: 11), () => subscription.cancel());
  }

  Future<void> _connect(BluetoothDevice device) async {
    _updateStatus(BleConnectionStatus.connecting);
    _device = device;

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      final services = await device.discoverServices();
      final targetService =
          services.firstWhere((s) => s.uuid == BleUuids.serviceUuid);

      _barcodeChar = targetService.characteristics
          .firstWhere((c) => c.uuid == BleUuids.barcodeCharUuid);
      _resultChar = targetService.characteristics
          .firstWhere((c) => c.uuid == BleUuids.resultCharUuid);

      await _barcodeChar!.setNotifyValue(true);

      // مهم جدًا: نلغي أي مستمع قديم أول (لو كان موجود من اتصال سابق)
      // عشان ما يتراكم أكثر من مستمع على نفس الإشارة ويسبب تكرار
      await _barcodeCharSubscription?.cancel();
      _barcodeCharSubscription = _barcodeChar!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        final barcode = utf8.decode(value).trim();
        _barcodeController.add(barcode);
      });

      _updateStatus(BleConnectionStatus.connected);
    } catch (e) {
      _updateStatus(BleConnectionStatus.disconnected);
      rethrow;
    }
  }

  /// يرسل نتيجة التحليل للسوارة عشان تولّع اللمبة المناسبة
  /// '2' = آمن (أخضر) | '1' = تحذير (أصفر) | '0' = خطر (أحمر) | '3' = معلومات ناقصة (كل اللمبات تطفى)
  Future<void> sendResult(ResultStatus status) async {
    if (_resultChar == null) return; // السوارة غير متصلة، نتجاهل بصمت

    final String code;
    switch (status) {
      case ResultStatus.green:
        code = '2';
        break;
      case ResultStatus.orange:
        code = '1';
        break;
      case ResultStatus.red:
        code = '0';
        break;
      case ResultStatus.insufficientData:
      case ResultStatus.unknown:
        // الباك إند يفرّق بين unknown وinsufficientData، لكن الإسوارة
        // تعرضهما بنفس الشكل (كل اللمبات تنطفئ).
        code = '3';
        break;
    }

    await _resultChar!.write(utf8.encode(code), withoutResponse: false);
  }

  Future<void> disconnect() async {
    await _barcodeCharSubscription?.cancel();
    _barcodeCharSubscription = null;
    await _device?.disconnect();
    _updateStatus(BleConnectionStatus.disconnected);
  }
}