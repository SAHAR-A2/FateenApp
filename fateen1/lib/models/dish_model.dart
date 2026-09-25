class Dish {
  final String name;
  final List<String> estimatedIngredients;

  Dish({required this.name, required this.estimatedIngredients});

  /// Parses the FATEEN backend's `DishEstimationResponse`
  /// (POST /api/v1/vision/estimate-dish). The Gemini call itself now runs
  /// server-side (app/services/vision_service.py); this class no longer
  /// talks to Gemini's raw response shape directly.
  factory Dish.fromAiResponse(Map<String, dynamic> json) {
    return Dish(
      name: json['name'] ?? 'غير معروف',
      estimatedIngredients: List<String>.from(
        json['estimated_ingredients'] ?? [],
      ),
    );
  }
}
