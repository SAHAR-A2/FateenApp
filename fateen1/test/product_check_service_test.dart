import 'dart:convert';

import 'package:fateen/models/compatibility_result_model.dart';
import 'package:fateen/models/user_model.dart';
import 'package:fateen/services/api_client.dart';
import 'package:fateen/services/fateen_api_service.dart';
import 'package:fateen/services/product_check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'product_model_test.dart' show detailsJson;

AppUser _user() => AppUser.fromJson({
      'id': 'u1',
      'username': 'tester',
      'allergies': [
        {'tag': 'en:milk', 'severity': 'شديد'},
      ],
      'diseases': [],
    });

void _profileTests() {
  test('profile with missing optional fields still parses', () {
    final user = AppUser.fromJson({
      'id': 'u1',
      'allergies': [
        {'tag': 'en:peanuts'},
      ],
    });
    expect(user.allergies.single.tag, 'en:peanuts');
    expect(user.allergies.single.severity, '');
    expect(user.diseases, isEmpty);
  });

  test('profile load failure is shown as its message', () async {
    final client = MockClient((request) async =>
        http.Response.bytes(utf8.encode(jsonEncode(detailsJson)), 200));
    final service = ProductCheckService(
      api: FateenApiService(
          apiClient: ApiClient(baseUrl: 'http://api.test', httpClient: client)),
      currentUserId: () => 'u1',
      loadProfile: (_) async => throw 'حدث خطأ أثناء جلب بيانات المستخدم',
    );
    await expectLater(
      () => service.check('6281000000066'),
      throwsA(isA<ProductCheckException>().having(
          (e) => e.message, 'message', 'حدث خطأ أثناء جلب بيانات المستخدم')),
    );
  });
}

ProductCheckService _service(
  MockClient client, {
  String? userId = 'u1',
  AppUser? profile,
}) {
  final api = FateenApiService(
    apiClient: ApiClient(baseUrl: 'http://api.test', httpClient: client),
  );
  return ProductCheckService(
    api: api,
    currentUserId: () => userId,
    loadProfile: (_) async => profile,
  );
}

void main() {
  _profileTests();

  test('barcode -> details -> compatibility', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add('${request.method} ${request.url.path}');
      if (request.url.path.startsWith('/api/v1/products/details/')) {
        return http.Response.bytes(utf8.encode(jsonEncode(detailsJson)), 200);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['allergies'], [
        {'tag': 'en:milk', 'severity': 'شديد'},
      ]);
      return http.Response.bytes(
          utf8.encode(jsonEncode({'status': 'UNKNOWN', 'reason': 'غير مؤكد'})), 200);
    });

    final outcome = await _service(client, profile: _user()).check(' 6281000000066 ');

    expect(requested, [
      'GET /api/v1/products/details/barcode/6281000000066',
      'POST /api/v1/products/barcode/6281000000066/compatibility',
    ]);
    expect(outcome.product.name, 'Fateen Test Milk');
    expect(outcome.result.status, ResultStatus.unknown);
    expect(outcome.result.reason, 'غير مؤكد');
  });

  test('unknown barcode is a readable message, not an exception dump', () async {
    final client = MockClient((_) async => http.Response('{"detail":"x"}', 404));
    expect(
      () => _service(client, profile: _user()).check('0000000000000'),
      throwsA(isA<ProductCheckException>().having(
          (e) => e.message, 'message', contains('غير موجود'))),
    );
  });

  test('signed-out user is stopped before any request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    await expectLater(
      () => _service(client, userId: null).check('6281000000066'),
      throwsA(isA<ProductCheckException>()),
    );
    expect(calls, 0);
  });

  test('missing health profile does not call compatibility', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response.bytes(utf8.encode(jsonEncode(detailsJson)), 200);
    });
    await expectLater(
      () => _service(client, profile: null).check('6281000000066'),
      throwsA(isA<ProductCheckException>().having(
          (e) => e.message, 'message', contains('ملفك الصحي'))),
    );
    expect(paths.where((p) => p.endsWith('/compatibility')), isEmpty);
  });

  test('server errors surface the backend detail', () async {
    final client = MockClient((_) async =>
        http.Response.bytes(utf8.encode(jsonEncode({'detail': 'تعطل مؤقت'})), 503));
    expect(
      () => _service(client, profile: _user()).check('6281000000066'),
      throwsA(isA<ProductCheckException>().having(
          (e) => e.message, 'message', 'تعطل مؤقت')),
    );
  });

  test('barcode is URL-encoded in the request path', () async {
    final client = MockClient((request) async {
      expect(request.url.pathSegments.last, '12/34');
      return http.Response('{}', 404);
    });
    await expectLater(
      () => _service(client, profile: _user()).check('12/34'),
      throwsA(isA<ProductCheckException>()),
    );
  });
}
