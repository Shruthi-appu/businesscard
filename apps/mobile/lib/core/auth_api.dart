import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_problem.dart';

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.displayName,
    required this.email,
    required this.role,
  });

  final String accessToken;
  final String refreshToken;
  final String displayName;
  final String? email;
  final String role;
}

class WalletSnapshot {
  const WalletSnapshot({required this.displayName, required this.titles});

  final String displayName;
  final List<String> titles;

  bool get empty => titles.isEmpty;
}

class AuthApi {
  AuthApi({required this.client, required this.baseUrl});

  final http.Client client;
  final String baseUrl;

  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _auth('POST', '/v1/auth/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
    }, expected: 201);
  }

  Future<Session> login({required String email, required String password}) {
    return _auth('POST', '/v1/auth/login', {
      'email': email,
      'password': password,
    }, expected: 200);
  }

  Future<Session> refresh(String refreshToken) {
    return _auth('POST', '/v1/auth/refresh', {
      'refreshToken': refreshToken,
    }, expected: 200);
  }

  Future<void> logout(String refreshToken) async {
    await _send(
      'POST',
      '/v1/auth/logout',
      {'refreshToken': refreshToken},
      expected: 204,
    );
  }

  Future<WalletSnapshot> loadWallet(String accessToken) async {
    final me = await _send('GET', '/v1/me', null, token: accessToken, expected: 200);
    final cards = await _send(
      'GET',
      '/v1/cards',
      null,
      token: accessToken,
      expected: 200,
    );
    final items = cards['items'];
    final titles = <String>[];
    if (items is List) {
      for (final item in items) {
        if (item is Map && item['title'] is String) {
          titles.add(item['title'] as String);
        }
      }
    }
    return WalletSnapshot(
      displayName: me['displayName'] as String? ?? 'Member',
      titles: titles,
    );
  }

  Future<Session> _auth(
    String method,
    String path,
    Map<String, Object?> body, {
    required int expected,
  }) async {
    final json = await _send(method, path, body, expected: expected);
    return Session(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      displayName: (json['user'] as Map?)?['displayName'] as String? ?? 'Member',
      email: (json['user'] as Map?)?['email'] as String?,
      role: (json['user'] as Map?)?['role'] as String? ?? 'user',
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String? token,
    required int expected,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    try {
      final request = http.Request(method, uri)
        ..headers['content-type'] = 'application/json'
        ..headers['accept'] = 'application/json';
      if (token != null) request.headers['authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      final streamed = await client.send(request);
      response = await http.Response.fromStream(streamed);
    } on http.ClientException {
      throw const ApiProblem(
        status: 0,
        code: 'network_failure',
        title: "We couldn't reach Softxu.",
      );
    }
    if (response.statusCode == expected) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    }
    throw _problem(response);
  }

  ApiProblem _problem(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        return ApiProblem(
          status: response.statusCode,
          code: decoded['code'] as String? ?? 'request_error',
          title: decoded['title'] as String? ?? 'Request failed',
          fieldErrors: errors is List
              ? errors
                    .whereType<Map>()
                    .map((error) => error['message'])
                    .whereType<String>()
                    .toList()
              : const [],
        );
      }
    } catch (_) {
      // Fall through to a generic problem.
    }
    return ApiProblem(
      status: response.statusCode,
      code: response.statusCode == 403 ? 'forbidden' : 'request_error',
      title: 'Request failed',
    );
  }
}
