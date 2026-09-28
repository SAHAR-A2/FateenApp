import 'package:flutter/material.dart';

import '../models/compatibility_result_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'fateen_api_service.dart';
import 'firestore_service.dart';

/// A failure the user can act on, already phrased for display.
class ProductCheckException implements Exception {
  const ProductCheckException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ProductCheckOutcome {
  const ProductCheckOutcome({required this.product, required this.result});
  final Product product;
  final CompatibilityResult result;
}

/// The one flow every entry point (live scan, photo, search, favorites,
/// alternatives) uses to go from a barcode to a compatibility result:
/// product details from FateenDB, the user's health profile from Firestore,
/// then the backend's compatibility decision.
class ProductCheckService {
  ProductCheckService({
    FateenApiService? api,
    String? Function()? currentUserId,
    Future<AppUser?> Function(String userId)? loadProfile,
  })  : _api = api ?? FateenApiService(),
        _currentUserId = currentUserId ?? (() => AuthService().getCurrentUserId()),
        _loadProfile = loadProfile ?? ((id) => FirestoreService().getUserProfile(id));

  final FateenApiService _api;
  final String? Function() _currentUserId;
  final Future<AppUser?> Function(String userId) _loadProfile;

  Future<ProductCheckOutcome> check(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) {
      throw const ProductCheckException('لا يوجد باركود لهذا المنتج');
    }

    final userId = _currentUserId();
    if (userId == null) {
      throw const ProductCheckException('يلزم تسجيل الدخول لفحص المنتج');
    }

    try {
      final product = await _api.getProductByBarcode(barcode);
      if (product == null) {
        throw const ProductCheckException(
            'هذا المنتج غير موجود في قاعدة بيانات فطين بعد');
      }

      final AppUser? user;
      try {
        user = await _loadProfile(userId);
      } catch (e) {
        // FirestoreService throws display-ready strings.
        throw ProductCheckException(
            e is String ? e : 'تعذّر تحميل ملفك الصحي، حاول مرة أخرى');
      }
      if (user == null) {
        throw const ProductCheckException(
            'تعذّر تحميل ملفك الصحي، أكمل بياناتك من صفحة الملف الشخصي');
      }

      final result = await _api.getCompatibility(barcode: barcode, user: user);
      return ProductCheckOutcome(product: product, result: result);
    } on FateenApiException catch (e) {
      throw ProductCheckException(e.message);
    }
  }
}

/// Runs [ProductCheckService.check] and opens the result screen, or shows
/// the failure as a snack bar. Returns true when the result screen opened.
Future<bool> checkAndOpenResult(
  BuildContext context,
  String barcode, {
  bool replace = false,
  ProductCheckService? service,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final outcome = await (service ?? ProductCheckService()).check(barcode);
    final arguments = {
      'status': outcome.result.status.uiKey,
      'message': outcome.result.reason,
      'productName': outcome.product.name,
      'barcode': outcome.product.barcode,
      'product': outcome.product,
    };
    if (replace) {
      navigator.pushReplacementNamed('/result', arguments: arguments);
    } else {
      navigator.pushNamed('/result', arguments: arguments);
    }
    return true;
  } on ProductCheckException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('حدث خطأ غير متوقع، حاول مرة أخرى')),
    );
  }
  return false;
}
