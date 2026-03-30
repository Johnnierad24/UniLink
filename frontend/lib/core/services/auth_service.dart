import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class AuthService {
  static const _accessKey = 'unilink_access';
  static const _userKey = 'unilink_user';

  final SupabaseClient _supabase = Supabase.instance.client;
  final http.Client _client;
  SharedPreferences? _prefs;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<AuthResult> login(String login, String password) async {
    try {
      // Supabase Auth: login with email (use login as email if it contains @)
      String email = login;
      if (!login.contains('@')) {
        // For university ID, construct email or use as-is
        email = '$login@students.unilink.edu';
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        final prefs = await _getPrefs();
        await prefs.setString(_accessKey, response.session!.accessToken);

        // Get user data from Django using the Supabase token
        final userInfo =
            await _fetchUserFromDjango(response.session!.accessToken);
        if (userInfo != null) {
          await prefs.setString(_userKey, jsonEncode(userInfo.toJson()));
          return AuthResult.success(userInfo!);
        }

        // If Django fetch fails, create basic user from Supabase
        final user = response.user!;
        final basicUserInfo = UserInfo(
          id: user.id.hashCode,
          username: user.email?.split('@').first ?? 'user',
          email: user.email,
          role: 'student',
          campusId: null,
          departmentId: null,
        );
        await prefs.setString(_userKey, jsonEncode(basicUserInfo.toJson()));
        return AuthResult.success(basicUserInfo);
      }

      return AuthResult.failure('Login failed');
    } catch (e) {
      return AuthResult.failure(_getErrorMessage(e.toString()));
    }
  }

  Future<UserInfo?> _fetchUserFromDjango(String token) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/auth/me/');
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserInfo.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  String _getErrorMessage(String error) {
    if (error.contains('invalid_credentials')) return 'Invalid credentials';
    if (error.contains('user_not_found')) return 'User not found';
    if (error.contains('email_not_confirmed'))
      return 'Please verify your email';
    return 'Login failed';
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    final prefs = await _getPrefs();
    await prefs.remove(_accessKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getAccessToken() async {
    final session = _supabase.auth.currentSession;
    return session?.accessToken;
  }

  Future<UserInfo?> getStoredUser() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return UserInfo.fromJson(jsonDecode(raw));
  }

  Future<bool> isLoggedIn() async {
    final session = _supabase.auth.currentSession;
    return session != null;
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final token = await getAccessToken();
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    return _client.get(uri, headers: _headers(token));
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final token = await getAccessToken();
    return _client.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> patch(String path, {Map<String, dynamic>? body}) async {
    final token = await getAccessToken();
    return _client.patch(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
}

class UserInfo {
  final int id;
  final String username;
  final String? email;
  final String role;
  final int? campusId;
  final int? departmentId;

  UserInfo({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.campusId,
    this.departmentId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'] ?? json['id']?.hashCode ?? 0,
        username: json['username'] ?? json['email']?.split('@').first ?? 'user',
        email: json['email'],
        role: json['role'] ?? 'student',
        campusId: json['campus_id'] ?? json['campus']?['id'],
        departmentId: json['department_id'] ?? json['department']?['id'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'role': role,
        'campus_id': campusId,
        'department_id': departmentId,
      };

  bool get isStaff => role == 'staff' || role == 'admin';
}

class AuthResult {
  final bool success;
  final UserInfo? user;
  final String? error;

  AuthResult._({required this.success, this.user, this.error});

  factory AuthResult.success(UserInfo user) =>
      AuthResult._(success: true, user: user);
  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);
}
