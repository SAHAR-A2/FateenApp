/// A single ingredient/allergen/health-flag relationship as returned by the
/// FATEEN backend, each carrying its own evidence and confidence --
/// deliberately not collapsed into one product-level number.
class FateenRelationship {
  final String internalCode;
  final String name;
  final String relationshipType;
  final double confidenceLevel;
  final String? evidenceType;

  FateenRelationship({
    required this.internalCode,
    required this.name,
    required this.relationshipType,
    required this.confidenceLevel,
    this.evidenceType,
  });

  factory FateenRelationship.fromJson(Map<String, dynamic> json) {
    return FateenRelationship(
      internalCode: json['internal_code'] ?? '',
      name: json['name'] ?? '',
      relationshipType: json['relationship_type'] ?? '',
      confidenceLevel: (json['confidence_level'] as num?)?.toDouble() ?? 0.0,
      evidenceType: json['evidence_type'],
    );
  }
}

class FateenNutritionValue {
  final String nutritionType;
  final double amountValue;
  final String? unit;
  final double confidenceLevel;

  /// What the amount refers to, e.g. PER_100G or PER_SERVING. Null when the
  /// source did not state it.
  final String? measurementBasis;
  final String? evidenceType;

  FateenNutritionValue({
    required this.nutritionType,
    required this.amountValue,
    this.unit,
    required this.confidenceLevel,
    this.measurementBasis,
    this.evidenceType,
  });

  factory FateenNutritionValue.fromJson(Map<String, dynamic> json) {
    return FateenNutritionValue(
      nutritionType: json['nutrition_type'] ?? '',
      amountValue: (json['amount_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'],
      confidenceLevel: (json['confidence_level'] as num?)?.toDouble() ?? 0.0,
      measurementBasis: json['measurement_basis'],
      evidenceType: json['evidence_type'],
    );
  }
}

/// MIGRATION-PHASE PRODUCT MODEL.
///
/// This is deliberately a dual-shape model during the FATEEN backend
/// migration:
///   - The FATEEN-shaped fields (internalCode, lifecycleStatus,
///     confidenceLevel, imageUrl, ingredients, allergens, healthFlags,
///     nutrition) are the authoritative shape, populated by
///     Product.fromFateenDetailsJson / Product.fromSearchResultJson via
///     FateenApiService.
///   - The Open-Food-Facts-shaped fields (imageUrl, ingredientsText,
///     allergenTags, nutriments) are kept, UNCHANGED, so that call sites
///     not yet migrated in this pass (lib/logic/health_checker.dart,
///     lib/screens/favorites_screen.dart, lib/screens/search_screen.dart,
///     lib/screens/result_screen.dart, lib/screens/dish_scan_screen.dart)
///     keep compiling and behaving exactly as before.
///
/// Once every production call site uses the FATEEN-shaped fields and
/// nothing reads the OFF-shaped fields anymore, this class should be split
/// back into a single clean shape and the deprecated members below
/// removed. Do not add new consumers of the deprecated fields.
class Product {
  // --- FATEEN backend shape (new, authoritative) ------------------------
  final String internalCode;
  final String barcode;
  final String? description;
  final String? nameAr;
  final String? nameEn;
  final String lifecycleStatus;
  final double confidenceLevel;
  final List<FateenRelationship> ingredients;
  final List<FateenRelationship> allergens;
  final List<FateenRelationship> healthFlags;
  final List<FateenNutritionValue> nutrition;

  // --- Open Food Facts shape (legacy, deprecated, kept for transition) --
  final String name;

  /// Optional image URL returned by FateenDB when a product image is linked.
  final String imageUrl;
  @Deprecated(
    'Use the structured `ingredients` list instead. Kept only for '
    'lib/logic/health_checker.dart and other unmigrated legacy call sites.',
  )
  final String ingredientsText;
  @Deprecated(
    'Use the structured `allergens` list instead. Kept only for '
    'lib/logic/health_checker.dart and other unmigrated legacy call sites.',
  )
  final List<String> allergenTags;
  @Deprecated(
    'Use the structured `nutrition` list instead. Kept only for '
    'lib/logic/health_checker.dart and other unmigrated legacy call sites.',
  )
  final Map<String, dynamic> nutriments;

  Product({
    this.internalCode = '',
    required this.barcode,
    this.description,
    this.nameAr,
    this.nameEn,
    this.lifecycleStatus = '',
    this.confidenceLevel = 0.0,
    this.ingredients = const [],
    this.allergens = const [],
    this.healthFlags = const [],
    this.nutrition = const [],
    required this.name,
    this.imageUrl = '',
    this.ingredientsText = '',
    this.allergenTags = const [],
    this.nutriments = const {},
  });

  /// Parses the response of
  /// `GET /api/v1/products/details/barcode/{barcode}`. This is the FATEEN-
  /// authoritative path -- use this (via FateenApiService), not
  /// fromOpenFoodFacts, for any new code.
  factory Product.fromFateenDetailsJson(
    Map<String, dynamic> json, {
    required String barcode,
  }) {
    return Product(
      internalCode: json['internal_code'] ?? '',
      name: json['name'] ?? 'غير معروف',
      imageUrl: json['image_url'] ?? '',
      description: json['description'],
      nameAr: json['name_ar'],
      nameEn: json['name_en'],
      barcode: barcode,
      lifecycleStatus: json['lifecycle_status'] ?? '',
      confidenceLevel: (json['confidence_level'] as num?)?.toDouble() ?? 0.0,
      ingredients: ((json['ingredients'] as List?) ?? [])
          .map((e) => FateenRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
      allergens: ((json['allergens'] as List?) ?? [])
          .map((e) => FateenRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
      healthFlags: ((json['health_flags'] as List?) ?? [])
          .map((e) => FateenRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
      nutrition: ((json['nutrition'] as List?) ?? [])
          .map((e) => FateenNutritionValue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Parses one entry from `GET /api/v1/products/search` results (lighter
  /// than full details -- no ingredients/allergens yet; fetch full details
  /// separately via getProductByBarcode once a result is opened).
  factory Product.fromSearchResultJson(Map<String, dynamic> json) {
    return Product(
      internalCode: json['internal_code'] ?? '',
      name: json['name'] ?? 'غير معروف',
      imageUrl: json['image_url'] ?? '',
      description: json['description'],
      nameAr: json['name_ar'],
      nameEn: json['name_en'],
      barcode: json['barcode'] ?? '',
      lifecycleStatus: json['lifecycle_status'] ?? '',
      confidenceLevel: (json['confidence_level'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ---------------------------------------------------------------------
  // LEGACY (unchanged from before this migration) -- kept only so
  // unmigrated call sites keep compiling and behaving identically.
  // ---------------------------------------------------------------------

  @Deprecated(
    'Open Food Facts is no longer the authoritative product source for '
    'new code. Use Product.fromFateenDetailsJson or '
    'Product.fromSearchResultJson instead. This adapter exists only to '
    'keep unmigrated legacy call sites compiling during the FATEEN '
    'backend migration; do not add new callers.',
  )
  factory Product.fromOpenFoodFacts(Map<String, dynamic> json) {
    return Product(
      barcode: json['code']?.toString() ?? '',
      name: json['product_name'] ?? 'غير معروف',
      imageUrl: json['image_url'] ?? '',
      ingredientsText: json['ingredients_text'] ?? '',
      allergenTags: List<String>.from(json['allergens_tags'] ?? []),
      nutriments: Map<String, dynamic>.from(json['nutriments'] ?? {}),
    );
  }

  @Deprecated(
    'Legacy OFF-shaped JSON round-trip, unrelated to the FATEEN backend '
    'contract. Kept only for any unmigrated legacy call site.',
  )
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? 'غير معروف',
      imageUrl: json['imageUrl'] ?? '',
      ingredientsText: json['ingredientsText'] ?? '',
      allergenTags: List<String>.from(json['allergenTags'] ?? []),
      nutriments: Map<String, dynamic>.from(json['nutriments'] ?? {}),
    );
  }

  @Deprecated(
    'Legacy OFF-shaped JSON round-trip. Kept only for any unmigrated '
    'legacy call site.',
  )
  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'imageUrl': imageUrl,
      'ingredientsText': ingredientsText,
      'allergenTags': allergenTags,
      'nutriments': nutriments,
    };
  }

  @Deprecated(
    'Insufficient-data is now an authoritative backend decision '
    '(CompatibilityResult.status == insufficientData / unknown), not a '
    'client-side heuristic. Kept only for any unmigrated legacy call site; '
    'do not use in new code.',
  )
  bool hasInsufficientData() {
    return ingredientsText.isEmpty && nutriments.isEmpty;
  }
}
