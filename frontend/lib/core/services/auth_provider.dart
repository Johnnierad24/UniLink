import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  UserInfo? _user;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  UserInfo? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isStaff => _user?.isStaff ?? false;
  String? get error => _error;
  bool get initialized => _initialized;
  AuthService get authService => _auth;

  Future<void> init() async {
    _user = await _auth.getStoredUser();
    _initialized = true;
    notifyListeners();
  }

  Future<bool> login(String login, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await _auth.login(login, password);

    _loading = false;
    if (result.success) {
      _user = result.user;
      _error = null;
    } else {
      _error = result.error;
    }
    notifyListeners();
    return result.success;
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    notifyListeners();
  }
}
