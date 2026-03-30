import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  String? _successMessage;
  int _step = 1;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAndReset() async {
    if (_step == 1) {
      await _verifyUser();
    } else {
      await _resetPassword();
    }
  }

  Future<void> _verifyUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = AuthService();
      final res = await authService.post('/api/auth/token/', body: {
        'login': _loginCtrl.text,
        'password': 'temp_verify_password_check',
      });

      if (res.statusCode == 200) {
        setState(() {
          _step = 2;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'User not found. Please check your University ID or Email.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    if (_newPassCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = AuthService();
      final res = await authService.post('/api/auth/password-reset/', body: {
        'login': _loginCtrl.text,
        'new_password': _newPassCtrl.text,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset successfully! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final body = jsonDecode(res.body);
        final message = body['error']?['message'] ?? 'Failed to reset password';
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 1 ? 'Reset Password' : 'New Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _step == 1 ? Icons.person_search : Icons.lock_reset,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _step == 1 ? 'Find your account' : 'Set new password',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'Enter your University ID or Email'
                      : 'Enter a strong password',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_step == 1) ...[
                  TextFormField(
                    controller: _loginCtrl,
                    decoration: const InputDecoration(
                      labelText: 'University ID or Email',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _verifyAndReset,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Find Account'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _verifyAndReset,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reset Password'),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (_step == 2) {
                      setState(() => _step = 1);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                      _step == 2 ? 'Use different account' : 'Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
