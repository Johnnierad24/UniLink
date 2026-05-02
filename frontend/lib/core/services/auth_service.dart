import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/user_role.dart';

class AuthService {
  static const _accessKey = 'unilink_access';
  static const _refreshKey = 'unilink_refresh';
  static const _userKey = 'unilink_user';

  final http.Client _client;
  SharedPreferences? _prefs;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<AuthResult> login(String login, String password) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiBaseUrl/api/auth/token/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'login': login, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print('Login response: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await _getPrefs();
        await prefs.setString(_accessKey, data['access']);
        await prefs.setString(_refreshKey, data['refresh']);
        await prefs.setString(_userKey, jsonEncode(data['user']));
        return AuthResult.success(UserInfo.fromJson(data['user']));
      }

      print('Login failed: ${res.body}');
      final err =
          res.statusCode == 401 ? 'Invalid credentials' : 'Login failed';
      return AuthResult.failure(err);
    } catch (e) {
      print('Login error: $e');
      return AuthResult.failure('Connection error: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userKey);
  }

  // Check for active session - returns null to show welcome screen
  // (Supabase session check would go here if using Supabase auth)
  dynamic getSupabaseSession() => null;

  Future<void> clearStoredUser() async {
    final prefs = await _getPrefs();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_accessKey);
  }

  Future<UserInfo?> getStoredUser() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return UserInfo.fromJson(jsonDecode(raw));
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
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
  final UserRole role;
  final int? campusId;
  final int? departmentId;

  UserInfo(
      {required this.id,
      required this.username,
      this.email,
      required this.role,
      this.campusId,
      this.departmentId});

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'],
        username: json['username'],
        email: json['email'],
        role: UserRole.fromApi(json['role']),
        campusId: json['campus_id'],
        departmentId: json['department_id'],
      );

  UserCapabilities get capabilities => UserCapabilities(role);
  bool get isStudent => capabilities.isStudent;
  bool get isLecturer => capabilities.isLecturer;
  bool get isProcurement => capabilities.isProcurement;
  bool get isDirector => capabilities.isDirector;
  bool get isCoordinator => capabilities.isCoordinator;
  bool get isStaff => capabilities.isStaffLike;
  bool get canViewProcurement => capabilities.canViewProcurement;
  bool get canApproveProcurement => capabilities.canApproveProcurement;
  bool get canUseBookings => capabilities.canUseBookings;
  bool get canViewAllSchedules => capabilities.canViewAllSchedules;
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
