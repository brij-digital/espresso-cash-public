// @dart=3.9

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:solana/solana.dart';
import 'package:test/test.dart';

void main() {
  test('subscribe request is sent once websocket is ready', () async {
    final subscribeRequest = Completer<Map<String, dynamic>>();
    final server = await _bindServer((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((dynamic message) {
        if (!subscribeRequest.isCompleted) {
          subscribeRequest.complete(_decodeRequest(message));
          unawaited(socket.close());
        }
      });
    });
    addTearDown(() => server.close(force: true));

    final client = SubscriptionClient(_toWebSocketUri(server));
    addTearDown(client.close);

    final subscription = client.slotSubscribe().listen((_) {});
    addTearDown(subscription.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(subscribeRequest.isCompleted, isFalse);

    final request = await subscribeRequest.future.timeout(const Duration(seconds: 1));
    expect(request['method'], 'slotSubscribe');
  });

  test('cancel sends unsubscribe after subscription id is received', () async {
    final subscribeRequest = Completer<Map<String, dynamic>>();
    final unsubscribeRequest = Completer<Map<String, dynamic>>();
    final server = await _bindServer((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((dynamic message) {
        final payload = _decodeRequest(message);
        if (!subscribeRequest.isCompleted) {
          subscribeRequest.complete(payload);
          socket.add(
            json.encode(<String, dynamic>{'jsonrpc': '2.0', 'result': 77, 'id': payload['id']}),
          );

          return;
        }

        if (!unsubscribeRequest.isCompleted) {
          unsubscribeRequest.complete(payload);
          unawaited(socket.close());
        }
      });
    });
    addTearDown(() => server.close(force: true));

    final client = SubscriptionClient(_toWebSocketUri(server));
    addTearDown(client.close);

    final subscription = client.slotSubscribe().listen((_) {});
    final request = await subscribeRequest.future.timeout(const Duration(seconds: 1));
    expect(request['method'], 'slotSubscribe');

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await subscription.cancel();

    final unsubscribe = await unsubscribeRequest.future.timeout(const Duration(seconds: 1));
    expect(unsubscribe['method'], 'slotUnsubscribe');
    expect(unsubscribe['params'], <int>[77]);
  });

  test('cancel before websocket is ready does not send stale requests', () async {
    final receivedRequest = Completer<Map<String, dynamic>>();
    final server = await _bindServer((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final socket = await WebSocketTransformer.upgrade(request);
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 150)).then((_) => socket.close()),
      );
      socket.listen((dynamic message) {
        if (!receivedRequest.isCompleted) {
          receivedRequest.complete(_decodeRequest(message));
        }
      });
    });
    addTearDown(() => server.close(force: true));

    final client = SubscriptionClient(_toWebSocketUri(server));
    addTearDown(client.close);

    final subscription = client.slotSubscribe().listen((_) {});
    await subscription.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(receivedRequest.isCompleted, isFalse);
  });
}

Future<HttpServer> _bindServer(Future<void> Function(HttpRequest request) onRequest) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) => unawaited(onRequest(request)));

  return server;
}

Uri _toWebSocketUri(HttpServer server) =>
    Uri(scheme: 'ws', host: server.address.address, port: server.port);

Map<String, dynamic> _decodeRequest(dynamic message) =>
    json.decode(message as String) as Map<String, dynamic>;
