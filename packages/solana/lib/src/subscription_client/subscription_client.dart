// @dart=3.9
import 'dart:async';
import 'dart:convert';

import 'package:solana/src/rpc/dto/account.dart';
import 'package:solana/src/rpc/dto/commitment.dart';
import 'package:solana/src/rpc/dto/encoding.dart';
import 'package:solana/src/rpc/dto/logs.dart';
import 'package:solana/src/rpc/dto/program_filter.dart';
import 'package:solana/src/rpc/dto/slot.dart';
import 'package:solana/src/subscription_client/abstract_message.dart';
import 'package:solana/src/subscription_client/error_message.dart';
import 'package:solana/src/subscription_client/logs_filter.dart';
import 'package:solana/src/subscription_client/notification_message.dart';
import 'package:solana/src/subscription_client/optional_error.dart';
import 'package:solana/src/subscription_client/subscribed_message.dart';
import 'package:solana/src/subscription_client/subscription_client_exception.dart';
import 'package:solana/src/subscription_client/web_socket_channel_factory.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Provides a websocket based connection to Solana.
class SubscriptionClient {
  /// [pingInterval] and [connectTimeout] are honored on IO platforms.
  /// On web they are accepted for API compatibility and ignored.
  SubscriptionClient(Uri uri, {Duration? pingInterval, Duration? connectTimeout}) {
    final channel = createWebSocketChannel(
      uri,
      pingInterval: pingInterval,
      connectTimeout: connectTimeout,
    );
    _channel = channel;
    _channelReady = channel.ready;
    _stream = channel.stream.asBroadcastStream();
  }

  SubscriptionClient.connect(String url) : this(Uri.parse(url));

  /// Subscribe to all incoming messages.
  Stream<SubscriptionMessage> allMessages() => _stream.map(_parse);

  /// Subscribe to an account with [address] to receive notifications when the
  /// lamports or data for a given account public key changes.
  ///
  /// Returns a [Stream] that can be used to listen for events. By cancelling the
  /// subscription returned by the `Stream.listen()` method of this stream
  /// client will automatically send `accountUnsubscribe` message;
  ///
  /// For [commitment] parameter description [see this document][1].
  ///
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [1]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Stream<Account> accountSubscribe(
    String address, {
    Commitment? commitment,
    Encoding encoding = Encoding.jsonParsed,
  }) => _subscribe<Account>(
    'account',
    params: <dynamic>[
      address,
      <String, String>{
        if (commitment != null) 'commitment': commitment.value,
        'encoding': encoding.value,
      },
    ],
  );

  /// Subscribe to transaction logging.
  ///
  /// Returns a [Stream] that can be used to listen for events. By cancelling the
  /// subscription returned by the `Stream.listen()` method of this stream
  /// client will automatically send `logsUnsubscribe` message;
  ///
  /// For [commitment] parameter description [see this document][1].
  ///
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [1]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Stream<Logs> logsSubscribe(LogsFilter filter, {Commitment? commitment}) => _subscribe<Logs>(
    'logs',
    params: <dynamic>[
      switch (filter) {
        LogsFilterAll() => 'all',
        LosgFilterAllWithVotes() => 'allWithVotes',
        LogsFilterMentions(:final pubKeys) => <String, List<String>>{'mentions': pubKeys},
      },
      if (commitment != null) <String, String>{'commitment': commitment.value},
    ],
  );

  /// Subscribe to a program to receive notifications when the lamports or data
  /// for a given account owned by the program changes.
  ///
  /// Returns a [Stream] that can be used to listen for events. By cancelling the
  /// subscription returned by the `Stream.listen()` method of this stream
  /// client will automatically send `programUnsubscribe` message;
  ///
  /// For [commitment] parameter description [see this document][1].
  ///
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [1]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Stream<dynamic> programSubscribe(
    String programId, {
    Encoding encoding = Encoding.jsonParsed,
    List<ProgramFilter>? filters,
    Commitment? commitment,
  }) => _subscribe<dynamic>(
    'program',
    params: <dynamic>[
      programId,
      <String, String>{'encoding': encoding.value},
      ...?filters,
      if (commitment != null) <String, String>{'commitment': commitment.value},
    ],
  );

  /// Subscribe to a transaction signature to receive notification when the
  /// transaction is confirmed On signatureNotification, the subscription is
  /// automatically cancelled.
  ///
  /// Returns a [Stream] that can be used to listen for events. By cancelling
  /// subscription returned by the `Stream.listen()` method of this stream
  /// client will automatically send `signatureUnsubscribe` message;
  ///
  /// For [commitment] parameter description [see this document][1].
  ///
  /// [Commitment.processed] is not supported as [commitment].
  ///
  /// [1]: https://docs.solana.com/developing/clients/jsonrpc-api#configuring-state-commitment
  Stream<OptionalError> signatureSubscribe(String signature, {Commitment? commitment}) =>
      _subscribe<OptionalError>(
        'signature',
        params: <dynamic>[
          signature,
          if (commitment != null) <String, String>{'commitment': commitment.value},
        ],
        singleShot: true,
      );

  /// Subscribe to receive notification anytime a slot is processed by the
  /// validator.
  ///
  /// Returns a [Stream] that can be used to listen for events. By cancelling the
  /// subscription returned by the `Stream.listen()` method of this stream
  /// client will automatically send `slotUnsubscribe` message;
  /// from Solana.
  Stream<Slot> slotSubscribe() => _subscribe<Slot>('slot');

  /// Subscribe to receive notification anytime a new root is set by the
  /// validator.
  ///
  /// Returns a [Stream] that can be used to listen for events. By cancelling the
  /// subscription returned by the `Stream.listen()` method of this stream
  /// client will automatically send `rootUnsubscribe` message;
  /// from Solana.
  Stream<int> rootSubscribe() => _subscribe<int>('root');

  /// Dispose this object and cancel any existing subscription.
  void close() {
    _isClosed = true;
    _channel.sink.close();
  }

  static int _requestId = 1;

  late final WebSocketChannel _channel;
  late final Future<void> _channelReady;
  late final Stream<dynamic> _stream;

  bool _isClosed = false;

  Stream<T> _subscribe<T>(String method, {List<dynamic>? params, bool singleShot = false}) {
    if (_isClosed) {
      throw StateError('Subscribe should not be called after close.');
    }

    final controller = StreamController<T>();

    controller.onListen = () {
      int? subscriptionId;
      var subscribeRequestSent = false;
      var subscriptionCancelled = false;
      final requestId = _requestId++;

      final StreamSubscription<dynamic> subscription = _stream.listen(
        (dynamic event) {
          final message = _parse(event);
          if (message is SubscribedMessage) {
            if (message.id != requestId) return;

            subscriptionId = message.result;
          } else if (message is ErrorMessage) {
            if (message.id != requestId) return;

            controller.addError(SubscriptionClientException(message.error));
          } else if (message is NotificationMessage) {
            if (message.subscription != subscriptionId) return;

            if (singleShot) subscriptionId = null;

            // ignore: avoid-type-casts, controlled type
            controller.add(message.value as T);
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );

      unawaited(
        _channelReady.then((_) {
          if (_isClosed || subscriptionCancelled) return;

          subscribeRequestSent = true;
          _sendRequest(requestId, '${method}Subscribe', params);
        }, onError: (_, _) {}),
      );

      controller.onCancel = () async {
        subscriptionCancelled = true;
        await subscription.cancel();

        if (!subscribeRequestSent) return;

        final id = subscriptionId;
        if (id == null) return;

        _sendRequest(_requestId++, '${method}Unsubscribe', <int>[id]);
      };
    };

    return controller.stream;
  }

  SubscriptionMessage _parse(dynamic event) {
    if (event is String) {
      // ignore: avoid-type-casts, controlled type
      final parsed = json.decode(event) as Map<String, dynamic>;

      return SubscriptionMessage.fromJson(parsed);
    }

    throw FormatException('unexpected type received through the websocket ${event.runtimeType}');
  }

  void _sendRequest(int id, String method, List<dynamic>? params) {
    // If connection is already closed, ignore the request.
    // Otherwise, it will try to send unsubscription request when
    // the client just closes the connection instead of unsubscribing.
    if (_isClosed) return;

    final payload = json.encode(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    });

    _channel.sink.add(payload);
  }
}
