import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

const networkUnavailableMessage =
    'No internet connection. Check your connection and try again.';

String? networkErrorMessage(Object error) {
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return networkUnavailableMessage;
  }

  final message = error.toString().toLowerCase();
  if (message.contains('failed host lookup') ||
      message.contains('failed to fetch') ||
      message.contains('network request failed') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('connection reset by peer') ||
      message.contains('connection closed before full header') ||
      message.contains('no address associated with hostname')) {
    return networkUnavailableMessage;
  }
  return null;
}
