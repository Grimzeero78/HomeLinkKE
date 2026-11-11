// HuntInKE — API client. Talks to the SAME backend as the website
// (https://homelinkke.pages.dev/api — Cloudflare Pages Functions + D1),
// with the SAME Bearer token scheme, so one account works on both.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String kApiBase = 'https://homelinkke.pages.dev/api';
const String kWebBase = 'https://homelinkke.pages.dev';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  Api(this.token);
  String? token;
  final http.Client _c = http.Client();


  Map<String, String> _h() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<Map<String, dynamic>> _run(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$kApiBase$path');
    late http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_h());
      if (body != null) req.body = jsonEncode(body);
      res = await _c.send(req).timeout(const Duration(seconds: 18)).then(http.Response.fromStream);
    } on TimeoutException {
      throw ApiException('The internet is slow right now — try again.');
    } catch (_) {
      throw ApiException('No internet connection');
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Server error (${res.statusCode})', res.statusCode);
    }
    if (res.statusCode == 401) {
      // session expired or invalid — caller resets signed-in state
      throw ApiException((data['error'] ?? 'Please sign in first').toString(), 401);
    }
    if (data['ok'] != true) {
      throw ApiException((data['error'] ?? 'Something went wrong').toString(), res.statusCode);
    }
    return data;
  }

  static Map<String, String> qs(Map<String, dynamic> q) {
    q.removeWhere((k, v) => v == null || (v is String && v.isEmpty) || (v is num && v <= 0));
    return q.map((k, v) => MapEntry(Uri.encodeQueryComponent(k), Uri.encodeQueryComponent(v.toString())));
  }

  // ---------- auth ----------
  Future<Map<String, dynamic>> register(Map<String, dynamic> b) => _run('POST', '/register', b);
  Future<Map<String, dynamic>> login(String username, String password) =>
      _run('POST', '/login', {'username': username, 'password': password});
  Future<void> logout() async {
    try {
      await _run('POST', '/logout');
    } catch (_) {}
  }

  Future<String> hint(String username) async {
    final r = await _run('GET', '/hint/${Uri.encodeComponent(username)}');
    return (r['hint'] ?? '').toString();
  }

  Future<Map<String, dynamic>> me() => _run('GET', '/me');
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> b) => _run('PUT', '/me', b);
  Future<void> verify(Map<String, dynamic> docs) => _run('POST', '/verify', docs);
  Future<Map<String, dynamic>> settings() => _run('GET', '/settings');

  // ---------- listings ----------
  Future<List<dynamic>> listings({
    String? q, String? town, String? area, String? ptype, String? furnishing,
    num? min, num? max, String? amenities, String? sort, String? bt, int limit = 60,
  }) async {
    final s = qs({
      'q': q, 'town': town, 'area': area, 'ptype': ptype, 'furnishing': furnishing,
      'min': min, 'max': max, 'amenities': amenities, 'sort': sort, 'bt': bt, 'limit': limit,
    }).entries.map((e) => '${e.key}=${e.value}').join('&');
    final r = await _run('GET', '/listings${s.isEmpty ? '' : '?$s'}');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> listing(int id) => _run('GET', '/listings/$id');
  Future<Map<String, dynamic>> createListing(Map<String, dynamic> b) => _run('POST', '/listings', b);
  Future<void> updateListing(int id, Map<String, dynamic> b) async => _run('PUT', '/listings/$id', b);
  Future<void> deleteListing(int id) async => _run('DELETE', '/listings/$id');
  Future<Map<String, dynamic>> setStatus(int id, int vacant) =>
      _run('POST', '/listings/$id/status', {'vacant': vacant});
  Future<void> view(int id) async {
    try { await _run('POST', '/listings/$id/view'); } catch (_) {}
  }

  Future<void> report(int id, String reason, String note) =>
      _run('POST', '/listings/$id/report', {'reason': reason, 'note': note});
  Future<void> boost(int id, String mpesaCode, String senderName) =>
      _run('POST', '/listings/$id/boost', {'mpesaCode': mpesaCode, 'senderName': senderName});

  // ---------- favourites / mine ----------
  Future<List<dynamic>> myListings() async {
    final r = await _run('GET', '/my/listings');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<List<dynamic>> myFavorites() async {
    final r = await _run('GET', '/my/favorites');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<List<dynamic>> myBoosts() async {
    final r = await _run('GET', '/my/boosts');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<bool> toggleFavorite(int id) async {
    final r = await _run('POST', '/favorites/$id');
    return r['on'] == true;
  }

  // ---------- chat ----------
  Future<int> openConv(int listingId) async {
    final r = await _run('POST', '/convs', {'listingId': listingId});
    return (r['id'] as num).toInt();
  }

  Future<List<dynamic>> convs() async {
    final r = await _run('GET', '/convs');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> conv(int id) => _run('GET', '/convs/$id');
  Future<Map<String, dynamic>> messages(int convId, {int after = 0}) =>
      _run('GET', '/convs/$convId/messages?after=$after');
  Future<int> send(int convId, String text) async {
    final r = await _run('POST', '/convs/$convId/messages', {'text': text});
    return (r['id'] as num).toInt();
  }

  Future<void> editMsg(int convId, int mid, String text) =>
      _run('PATCH', '/convs/$convId/messages/$mid', {'text': text});
  Future<void> deleteMsg(int convId, int mid, {bool all = false}) =>
      _run('DELETE', '/convs/$convId/messages/$mid?scope=${all ? 'all' : 'me'}');
  Future<void> typing(int convId) async => _run('POST', '/convs/$convId/typing', {});

  Future<int> unread() async {
    final r = await _run('GET', '/unread');
    return (r['n'] as num?)?.toInt() ?? 0;
  }

  // ---------- admin ----------
  Future<Map<String, dynamic>> adminCounts() => _run('GET', '/admin/counts');
  Future<Map<String, dynamic>> adminStats() => _run('GET', '/admin/stats');
  Future<List<dynamic>> adminVerifications() async {
    final r = await _run('GET', '/admin/verifications');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<void> adminVerify(int uid, bool approve, String note) =>
      _run('POST', '/admin/verify/$uid', {'decision': approve ? 'approve' : 'reject', 'note': note});
  Future<List<dynamic>> adminBoosts() async {
    final r = await _run('GET', '/admin/boosts');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<void> adminBoost(int id, bool approve) =>
      _run('POST', '/admin/boosts/$id', {'decision': approve ? 'approve' : 'decline'});
  Future<List<dynamic>> adminReports() async {
    final r = await _run('GET', '/admin/reports');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<void> adminReport(int id, String action) =>
      _run('POST', '/admin/reports/$id', {'action': action}); // delete | remove | resolve
  Future<List<dynamic>> adminListings() async {
    final r = await _run('GET', '/admin/listings');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<void> adminListingAction(int id, String action) =>
      _run('POST', '/admin/listings/$id/$action'); // remove | restore | delete
  Future<List<dynamic>> adminUsers() async {
    final r = await _run('GET', '/admin/users');
    return (r['items'] ?? []) as List<dynamic>;
  }

  Future<void> adminSuspend(int id, bool on) => _run('POST', '/admin/users/$id/suspend', {'on': on});
  Future<void> adminDeleteUser(int id) => _run('POST', '/admin/users/$id/delete', {});
}
