// ignore_for_file: avoid-unused-parameters

import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(
  Uri uri, {
  Duration? pingInterval,
  Duration? connectTimeout,
}) => WebSocketChannel.connect(uri);
