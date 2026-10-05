import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:calimind/core/utils/network_error_utils.dart';

void main() {
  group('networkErrorMessage', () {
    test('returns a friendly message for common connection failures', () {
      expect(
        networkErrorMessage(const SocketException('host lookup failed')),
        networkUnavailableMessage,
      );
      expect(
        networkErrorMessage(http.ClientException('request failed')),
        networkUnavailableMessage,
      );
      expect(
        networkErrorMessage(TimeoutException('request timed out')),
        networkUnavailableMessage,
      );
      expect(
        networkErrorMessage(const FormatException('Failed to fetch')),
        networkUnavailableMessage,
      );
    });

    test('leaves unrelated errors for their existing handlers', () {
      expect(networkErrorMessage(FormatException('invalid response')), isNull);
    });
  });
}
