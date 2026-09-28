import 'package:fateen/models/product_model.dart';
import 'package:fateen/widgets/product_details_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'product_model_test.dart' show detailsJson;

Widget _host(Product product) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(child: ProductDetailsPanel(product: product)),
        ),
      ),
    );

void main() {
  testWidgets('shows allergens, ingredients and nutrition with basis', (tester) async {
    final json = Map<String, dynamic>.from(detailsJson)
      ..['allergens'] = [
        ...detailsJson['allergens'] as List,
        {
          'internal_code': 'SOY',
          'name': 'Soy',
          'relationship_type': 'MAY_CONTAIN_ALLERGEN',
          'confidence_level': 0.7,
        },
      ];
    await tester.pumpWidget(
        _host(Product.fromFateenDetailsJson(json, barcode: '6281000000066')));

    expect(find.text('يحتوي: Milk'), findsOneWidget);
    expect(find.text('قد يحتوي: Soy'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget); // ingredient chip
    expect(find.text('الطاقة'), findsOneWidget);
    expect(find.text('61 سعرة'), findsOneWidget);
    expect(find.text('لكل 100 مل'), findsOneWidget);
  });

  testWidgets('states missing sections instead of hiding them', (tester) async {
    await tester.pumpWidget(_host(Product(barcode: '1', name: 'Bare')));

    expect(find.text('لا تتوفر بيانات عن مسببات الحساسية لهذا المنتج'), findsOneWidget);
    expect(find.text('لا تتوفر قائمة المكونات لهذا المنتج'), findsOneWidget);
    expect(find.text('لا تتوفر القيم الغذائية لهذا المنتج'), findsOneWidget);
  });

  testWidgets('shows the printed ingredient list, Arabic first', (tester) async {
    final json = Map<String, dynamic>.from(detailsJson)
      ..['ingredients'] = []
      ..['ingredient_statements'] = {'en': 'Water, sugar', 'ar': 'ماء، سكر'};
    await tester.pumpWidget(
        _host(Product.fromFateenDetailsJson(json, barcode: '6281000000066')));

    expect(find.text('ماء، سكر'), findsOneWidget);
    expect(find.text('Water, sugar'), findsNothing);
    expect(find.text('لا تتوفر قائمة المكونات لهذا المنتج'), findsNothing);
  });

  test('formats amounts without noise', () {
    expect(ProductDetailsPanel.formatAmount(61), '61');
    expect(ProductDetailsPanel.formatAmount(4.8), '4.8');
    expect(ProductDetailsPanel.formatAmount(0.125), '0.13');
    expect(ProductDetailsPanel.formatAmount(1.10), '1.1');
  });
}
