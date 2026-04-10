import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(
  Uri uri, {
  Duration? pingInterval,
  Duration? connectTimeout,
}) => IOWebSocketChannel.connect(uri, pingInterval: pingInterval, connectTimeout: connectTimeout);
