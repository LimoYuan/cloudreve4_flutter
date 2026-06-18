import 'dart:io';

import 'package:dio/io.dart';
import 'package:http/io_client.dart';

/// Creates HTTP clients that always connect directly.
///
/// Windows may inherit HTTP_PROXY / HTTPS_PROXY / system proxy settings from the
/// environment. For this app we want normal network access and must not silently
/// route Cloudreve traffic through 127.0.0.1 proxy ports.
class DirectHttpClientFactory {
  const DirectHttpClientFactory._();

  static HttpClient httpClient({Duration? connectionTimeout}) {
    final client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    if (connectionTimeout != null) {
      client.connectionTimeout = connectionTimeout;
    }
    return client;
  }

  static IOHttpClientAdapter dioAdapter({Duration? connectionTimeout}) {
    return IOHttpClientAdapter(
      createHttpClient: () => httpClient(connectionTimeout: connectionTimeout),
    );
  }

  static IOClient packageHttpClient({Duration? connectionTimeout}) {
    return IOClient(httpClient(connectionTimeout: connectionTimeout));
  }
}