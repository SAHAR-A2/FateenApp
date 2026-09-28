import 'package:fateen/models/compatibility_result_model.dart';
import 'package:fateen/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shape returned by GET /api/v1/products/details/barcode/{barcode}.
const detailsJson = <String, dynamic>{
  'internal_code': 'FATEEN_MILK_TEST',
  'name': 'Fateen Test Milk',
  'description': null,
  'confidence_level': 0.5,
  'lifecycle_status': 'ACTIVE',
  'image_url': null,
  'ingredients': [
    {
      'internal_code': 'MILK',
      'name': 'Milk',
      'relationship_type': 'CONTAINS_INGREDIENT',
      'amount_value': null,
      'unit': null,
      'confidence_level': 1.0,
      'evidence_type': 'LABEL',
    },
  ],
  'allergens': [
    {
      'internal_code': 'MILK',
      'name': 'Milk',
      'relationship_type': 'CONTAINS_ALLERGEN',
      'confidence_level': 1.0,
      'evidence_type': 'DATABASE',
    },
  ],
  'health_flags': [],
  'nutrition': [
    {
      'nutrition_type': 'ENERGY',
      'amount_value': 61,
      'unit': 'KCAL',
      'relationship_type': 'MEASURED_VALUE',
      'confidence_level': 0.9,
      'evidence_type': 'LABEL',
      'measurement_basis': 'PER_100ML',
    },
  ],
};

void main() {
  test('parses backend product details, including nutrition basis', () {
    final product =
        Product.fromFateenDetailsJson(detailsJson, barcode: '6281000000066');

    expect(product.barcode, '6281000000066');
    expect(product.name, 'Fateen Test Milk');
    expect(product.imageUrl, '');
    expect(product.allergens.single.relationshipType, 'CONTAINS_ALLERGEN');
    expect(product.ingredients.single.name, 'Milk');
    final energy = product.nutrition.single;
    expect(energy.amountValue, 61.0);
    expect(energy.unit, 'KCAL');
    expect(energy.measurementBasis, 'PER_100ML');
  });

  test('missing nutrition basis stays null, not a guessed default', () {
    final json = Map<String, dynamic>.from(detailsJson)
      ..['nutrition'] = [
        {'nutrition_type': 'SUGAR', 'amount_value': 4.8, 'unit': 'G', 'confidence_level': 0.9},
      ];
    final product = Product.fromFateenDetailsJson(json, barcode: '1');
    expect(product.nutrition.single.measurementBasis, isNull);
  });

  test('maps every backend compatibility status', () {
    const expected = {
      'SAFE': ResultStatus.green,
      'WARNING': ResultStatus.orange,
      'DANGER': ResultStatus.red,
      'UNKNOWN': ResultStatus.unknown,
      'INSUFFICIENT_DATA': ResultStatus.insufficientData,
      'SOMETHING_NEW': ResultStatus.unknown,
    };
    expected.forEach((backend, status) {
      final result = CompatibilityResult.fromBackendJson({'status': backend, 'reason': 'r'});
      expect(result.status, status, reason: backend);
    });
  });
}
