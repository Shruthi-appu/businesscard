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
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String displayName;
  final String? email;
  final String role;
  final String userId;
}

class SavedCard {
  const SavedCard({
    required this.id,
    required this.title,
    this.headline,
    this.company,
    this.isFavourite = false,
  });

  final String id;
  final String title;
  final String? headline;
  final String? company;
  final bool isFavourite;

  String get label {
    final line = headline?.trim();
    if (line != null && line.isNotEmpty) return line;
    return title;
  }
}

class WalletSnapshot {
  const WalletSnapshot({
    required this.displayName,
    this.titles = const [],
    this.cards = const [],
  });

  final String displayName;
  final List<String> titles;
  final List<SavedCard> cards;

  bool get empty => cards.isEmpty && titles.isEmpty;
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

  Future<WalletSnapshot> loadWallet(
    String accessToken, {
    String query = '',
    String filter = 'all',
  }) async {
    final me = await _send('GET', '/v1/me', null, token: accessToken, expected: 200);
    final params = <String, String>{};
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (filter != 'all') params['filter'] = filter;
    final cards = await _send(
      'GET',
      params.isEmpty ? '/v1/cards' : '/v1/cards?${Uri(queryParameters: params).query}',
      null,
      token: accessToken,
      expected: 200,
    );
    final saved = <SavedCard>[];
    final titles = <String>[];
    final items = cards['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final title = item['title'];
        if (title is! String) continue;
        final card = SavedCard(
          id: item['id'] as String? ?? '',
          title: title,
          headline: item['headline'] as String?,
          company: item['company'] as String?,
          isFavourite: item['isFavourite'] == true,
        );
        saved.add(card);
        titles.add(card.label);
      }
    }
    return WalletSnapshot(
      displayName: me['displayName'] as String? ?? 'Member',
      titles: titles,
      cards: saved,
    );
  }

  Future<String> readText(String path, {required String token}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final request = http.Request('GET', uri)
        ..headers['accept'] = 'application/json'
        ..headers['authorization'] = 'Bearer $token';
      final streamed = await client.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) return response.body;
      throw _problem(response);
    } on ApiProblem {
      rethrow;
    } on http.ClientException {
      throw const ApiProblem(
        status: 0,
        code: 'network_failure',
        title: "We couldn't reach Softxu.",
      );
    }
  }

  Future<Map<String, dynamic>> send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String? token,
    int expected = 200,
    Map<String, String>? headers,
  }) {
    return _send(method, path, body, token: token, expected: expected, headers: headers);
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
      userId: (json['user'] as Map?)?['id'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String? token,
    required int expected,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    try {
      final request = http.Request(method, uri)
        ..headers['content-type'] = 'application/json'
        ..headers['accept'] = 'application/json';
      if (headers != null) request.headers.addAll(headers);
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
