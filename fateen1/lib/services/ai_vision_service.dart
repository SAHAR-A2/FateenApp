import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../models/dish_model.dart';
import 'api_client.dart';

/// Dish-photo estimation, routed through the FATEEN backend
/// (`POST /api/v1/vision/estimate-dish`) instead of calling Gemini
/// directly from the client. The Gemini API key now lives only in the
/// backend's environment (GEMINI_API_KEY) -- see
/// app/services/vision_service.py -- and never reaches this app.
///
/// This class only returns an ESTIMATED name/ingredient list; it does not
/// decide product compatibility itself (that remains a separate step in
/// dish_scan_screen.dart, unrelated to the barcode/search compatibility
/// path documented in the FATEEN architecture audit).
class AiVisionService {
  AiVisionService({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();

  final ApiClient _client;

  Future<Dish> analyzeDishImage(XFile image) async {
    final Uint8List imageBytes = await image.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    try {
      final json = await _client.post(
        '/api/v1/vision/estimate-dish',
        body: {'image_base64': base64Image},
      );
      return Dish.fromAiResponse(json as Map<String, dynamic>);
    } on FateenApiException {
      throw 'حدث خطأ أثناء تحليل صورة الطبق';
    }
  }
}
