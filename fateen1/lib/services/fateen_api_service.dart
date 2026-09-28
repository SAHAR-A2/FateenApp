import '../models/product_model.dart';
import '../models/compatibility_result_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// Client-side gateway to the FATEEN backend's product/search/compatibility
/// API. This is the ONE path new code should use to reach product data or a
/// compatibility decision -- not Open Food Facts, not HealthChecker.
class FateenApiService {
  FateenApiService({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();

  final ApiClient _client;

  /// Looks up a product by barcode via the FATEEN backend (FateenDB) --
  /// not Open Food Facts. Returns null if the barcode is not found,
  /// mirroring the backend's 404 contract.
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final json =
          await _client.get(
          '/api/v1/products/details/barcode/${Uri.encodeComponent(barcode)}');
      return Product.fromFateenDetailsJson(
        json as Map<String, dynamic>,
        barcode: barcode,
      );
    } on FateenApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Searches FateenDB by product name. Returns an empty list for no
  /// matches (not an error).
  Future<List<Product>> searchProducts(String query,
      {String language = 'ar'}) async {
    final json = await _client.get('/api/v1/products/search',
        query: {'q': query, 'language': language});
    final results = (json as Map<String, dynamic>)['results'] as List;
    return results
        .map((r) => Product.fromSearchResultJson(r as Map<String, dynamic>))
        .toList();
  }

  /// The single authoritative compatibility check for a product against a
  /// user's allergy/health context. The backend -- not this method, not
  /// the UI -- decides SAFE/WARNING/DANGER/UNKNOWN/INSUFFICIENT_DATA.
  ///
  /// Only the allergy/disease context needed for evaluation is sent; the
  /// rest of the user's profile stays in Firestore (FateenDB is not a
  /// second copy of the user profile).
  Future<CompatibilityResult> getCompatibility({
    required String barcode,
    required AppUser user,
  }) async {
    final body = {
      'allergies': user.allergies
          .map((a) => {'tag': a.tag, 'severity': a.severity})
          .toList(),
      'diseases': user.diseases
          .map((d) => {'name': d.name, 'severity': d.severity})
          .toList(),
    };
    final json = await _client.post(
      '/api/v1/products/barcode/${Uri.encodeComponent(barcode)}/compatibility',
      body: body,
    );
    return CompatibilityResult.fromBackendJson(json as Map<String, dynamic>);
  }

  /// Backend-verified safe alternatives for a product, replacing the old
  /// "search by name -> filter with HealthChecker" flow entirely. Every
  /// candidate returned here was already confirmed SAFE by the backend's
  /// CompatibilityService -- this method does not filter or re-evaluate
  /// anything client-side.
  Future<List<Product>> getAlternatives({
    required String barcode,
    required AppUser user,
  }) async {
    final body = {
      'allergies': user.allergies
          .map((a) => {'tag': a.tag, 'severity': a.severity})
          .toList(),
      'diseases': user.diseases
          .map((d) => {'name': d.name, 'severity': d.severity})
          .toList(),
    };
    final json = await _client.post(
      '/api/v1/products/barcode/${Uri.encodeComponent(barcode)}/alternatives',
      body: body,
    );
    final alternatives = (json as Map<String, dynamic>)['alternatives'] as List;
    return alternatives
        .map((a) => Product.fromSearchResultJson(
            (a as Map<String, dynamic>)['product'] as Map<String, dynamic>))
        .toList();
  }

  void dispose() => _client.dispose();
}
