// @dart=3.9

@TestOn('browser')
library;

import 'package:solana/solana.dart';
import 'package:test/test.dart';

void main() {
  test('constructor path is usable in browser builds', () async {
    final client = SubscriptionClient.connect('http://localhost');
    addTearDown(client.close);

    final result = client.slotSubscribe().first.timeout(const Duration(seconds: 5));
    await expectLater(result, throwsA(anything));
  });
}
