import 'package:flutter_test/flutter_test.dart';
import 'package:form4x/services/api_service.dart';

void main() {
  test('mobile uses the same production backend as web', () {
    expect(
      ApiService.baseUrl,
      'https://formax-api.commandspes.tech',
    );
  });
}
