import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/issue.dart';
import '../models/issue_page.dart';
import '../models/issue_update.dart';

class ApiService {
  final _secureStorage = const FlutterSecureStorage();

  static const String defaultBaseUrl = 'https://mto-municipal.vercel.app';
  static const String kBaseUrlKey = 'api_base_url';
  static const String kSessionTokenKey = 'session_token';
  static const String kUserSessionKey = 'user_session';

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kBaseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kBaseUrlKey, url);
  }

  Future<String?> getSessionCookie() async {
    return await _secureStorage.read(key: kSessionTokenKey);
  }

  Future<void> _saveSessionCookie(String cookie) async {
    await _secureStorage.write(key: kSessionTokenKey, value: cookie);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: kSessionTokenKey);
    await _secureStorage.delete(key: kUserSessionKey);
  }

  // Get auth headers
  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final Map<String, String> headers = {};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }

    final cookie = await getSessionCookie();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // Auth: Fetch CSRF Token
  Future<({String token, String cookie})?> _fetchCsrfToken(
    String baseUrl,
  ) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/auth/csrf'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['csrfToken'] as String?;
        final setCookie = response.headers['set-cookie'];
        final csrfCookie = setCookie == null
            ? null
            : RegExp(
                r'(__Host-next-auth\.csrf-token=[^;,\s]+|next-auth\.csrf-token=[^;,\s]+)',
              ).firstMatch(setCookie)?.group(1);

        if (token != null && csrfCookie != null) {
          return (token: token, cookie: csrfCookie);
        }
      }
    } catch (e) {
      debugPrint('CSRF fetch error: $e');
    }
    return null;
  }

  // Auth: Login
  Future<User> login(String email, String password) async {
    final baseUrl = await getBaseUrl();

    // 1. Get CSRF Token
    final csrf = await _fetchCsrfToken(baseUrl);
    if (csrf == null) {
      throw Exception('Failed to obtain security token from server.');
    }

    // 2. Perform Login POST
    final loginUrl = Uri.parse('$baseUrl/api/auth/callback/credentials');
    final response = await http.post(
      loginUrl,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': csrf.cookie,
      },
      body: {
        'email': email,
        'password': password,
        'csrfToken': csrf.token,
        'callbackUrl': baseUrl,
        'json': 'true',
        'redirect': 'false',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed: Invalid credentials or connection issue.');
    }

    final body = json.decode(response.body);
    if (body['error'] != null) {
      throw Exception('Authentication failed: ${body['error']}');
    }

    // 3. Extract Session Cookie
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) {
      throw Exception(
        'Authentication succeeded, but session cookie was not returned.',
      );
    }

    // Capture the cookie name and value (e.g. next-auth.session-token=...)
    final sessionTokenMatch = RegExp(
      r'(next-auth\.session-token=[^;]+)',
    ).firstMatch(setCookie);
    final secureTokenMatch = RegExp(
      r'(__Secure-next-auth\.session-token=[^;]+)',
    ).firstMatch(setCookie);

    String? sessionCookie;
    if (secureTokenMatch != null) {
      sessionCookie = secureTokenMatch.group(1);
    } else if (sessionTokenMatch != null) {
      sessionCookie = sessionTokenMatch.group(1);
    }

    sessionCookie ??= setCookie.split(';').first;

    await _saveSessionCookie(sessionCookie);

    // 4. Retrieve User details via /api/auth/session
    return await fetchProfile(baseUrl, sessionCookie);
  }

  // Fetch User profile using current session cookie
  Future<User> fetchProfile([String? baseUrl, String? cookie]) async {
    baseUrl ??= await getBaseUrl();
    cookie ??= await getSessionCookie();

    if (cookie == null) {
      throw Exception('Not authenticated.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/session'),
      headers: {'Cookie': cookie},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null || data['user'] == null) {
        throw Exception('No active session found.');
      }

      final userData = data['user'];
      // NextAuth returns { name, email, image, role, id }
      final user = User(
        id: userData['id'] ?? userData['email'] ?? '',
        name: userData['name'] ?? '',
        email: userData['email'] ?? '',
        role: userData['role'] ?? 'read-only',
      );

      // Cache user details locally
      await _secureStorage.write(
        key: kUserSessionKey,
        value: json.encode(user.toJson()),
      );
      return user;
    } else {
      throw Exception(
        'Session verification failed with status: ${response.statusCode}',
      );
    }
  }

  Future<User?> getCachedUser() async {
    try {
      final userStr = await _secureStorage.read(key: kUserSessionKey);
      if (userStr != null) {
        return User.fromJson(json.decode(userStr));
      }
    } catch (e) {
      debugPrint('Error getting cached user: $e');
    }
    return null;
  }

  Future<IssuePage> fetchIssuesPage({
    required int page,
    int pageSize = 30,
    String? status,
    String? category,
    String? title,
    String? assignedTo,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': pageSize.toString(),
    };
    if (status != null && status != 'all') queryParams['status'] = status;
    if (category != null && category != 'all') {
      queryParams['category'] = category;
    }
    if (title != null && title.isNotEmpty) {
      queryParams['title'] = title;
      queryParams['road'] = title;
    }
    if (assignedTo != null && assignedTo != 'all') {
      queryParams['assigned_to'] = assignedTo;
    }

    final uri = Uri.parse(
      '$baseUrl/api/issues',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final dynamic decoded = json.decode(response.body);
      final List<dynamic> rawItems;
      int? total;
      bool? serverHasMore;

      if (decoded is List) {
        rawItems = decoded;
      } else if (decoded is Map<String, dynamic>) {
        rawItems =
            (decoded['items'] ?? decoded['issues'] ?? decoded['data'] ?? [])
                as List<dynamic>;
        total = (decoded['total'] ?? decoded['pagination']?['total']) as int?;
        serverHasMore =
            (decoded['has_more'] ??
                    decoded['hasMore'] ??
                    decoded['pagination']?['hasMore'])
                as bool?;
      } else {
        throw Exception('Unexpected issues response.');
      }

      // Older servers may ignore page/limit and return the complete array.
      final serverIgnoredPaging = rawItems.length > pageSize;
      final start = serverIgnoredPaging ? (page - 1) * pageSize : 0;
      final pageItems = serverIgnoredPaging
          ? rawItems.skip(start).take(pageSize).toList()
          : rawItems;
      final items = pageItems
          .map((item) => Issue.fromJson(item as Map<String, dynamic>))
          .toList();
      final hasMore =
          serverHasMore ??
          (serverIgnoredPaging
              ? start + items.length < rawItems.length
              : items.length == pageSize);

      return IssuePage(
        items: items,
        page: page,
        pageSize: pageSize,
        hasMore: hasMore,
        total: total ?? (serverIgnoredPaging ? rawItems.length : null),
      );
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to fetch issues: ${response.statusCode}');
    }
  }

  Future<List<Issue>> fetchIssues({
    String? status,
    String? category,
    String? title,
    String? assignedTo,
  }) async {
    return (await fetchIssuesPage(
      page: 1,
      pageSize: 50,
      status: status,
      category: category,
      title: title,
      assignedTo: assignedTo,
    )).items;
  }

  // Fetch a single issue
  Future<Issue> fetchIssueDetails(String id) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/api/issues/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Issue.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load issue details.');
    }
  }

  Future<List<IssueUpdate>> fetchIssueUpdates(String issueId) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/issues/$issueId/updates'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data
          .map((item) => IssueUpdate.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception(_responseError(response, 'Failed to load issue updates.'));
  }

  Future<IssueUpdate> addIssueUpdate(String issueId, String notes) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/issues/$issueId/updates'),
      headers: headers,
      body: json.encode({'notes': notes}),
    );

    if (response.statusCode == 201) {
      return IssueUpdate.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_responseError(response, 'Failed to add issue update.'));
  }

  String _responseError(http.Response response, String fallback) {
    try {
      final body = json.decode(response.body);
      if (body is Map<String, dynamic> && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {
      // Use the user-friendly fallback when the response is not JSON.
    }
    return fallback;
  }

  // Create new issue (Multipart Upload)
  Future<Issue> createIssue({
    required String title,
    required String category,
    required String description,
    required String gpsLocation,
    required List<String> localPhotoPaths,
  }) async {
    final baseUrl = await getBaseUrl();
    final cookie = await getSessionCookie();

    final uri = Uri.parse('$baseUrl/api/issues');
    final request = http.MultipartRequest('POST', uri);

    if (cookie != null) {
      request.headers['Cookie'] = cookie;
    }

    request.fields['title'] = title;
    request.fields['road'] = title;
    request.fields['category'] = category;
    request.fields['description'] = description;
    request.fields['gps_location'] = gpsLocation;

    // Attach photos
    for (String path in localPhotoPaths) {
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'photos[]', // The web backend supports photos[] or photos
              file.path,
            ),
          );
        }
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return Issue.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to submit issue (Status: ${response.statusCode})',
      );
    }
  }

  // Update issue details/status (PUT)
  Future<Issue> updateIssue(String id, Map<String, dynamic> updates) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders(isJson: true);

    final response = await http.put(
      Uri.parse('$baseUrl/api/issues/$id'),
      headers: headers,
      body: json.encode({
        ...updates,
        if (updates['title'] != null) 'road': updates['title'],
      }),
    );

    if (response.statusCode == 200) {
      return Issue.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to update issue.');
    }
  }

  // Delete issue (DELETE)
  Future<void> deleteIssue(String id) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders(isJson: false);

    final response = await http.delete(
      Uri.parse('$baseUrl/api/issues/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to delete issue.');
    }
  }

  // Fetch users directory (for admin assignment list)
  Future<List<User>> fetchUsers() async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/api/users'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((u) => User.fromJson(u)).toList();
    } else {
      throw Exception('Failed to fetch user directory.');
    }
  }
}
