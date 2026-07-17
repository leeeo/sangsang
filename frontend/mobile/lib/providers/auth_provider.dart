import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/user.dart';

// Google OAuth 클라이언트 ID
// 발급: https://console.cloud.google.com/apis/credentials
// --dart-define=GOOGLE_CLIENT_ID=<your-client-id> 로 주입하거나
// 아래 기본값을 직접 교체하세요.
const _kGoogleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '', // TODO: Google Cloud Console에서 발급한 클라이언트 ID 입력
);

final _googleSignIn = GoogleSignIn(
  clientId: _kGoogleClientId.isNotEmpty ? _kGoogleClientId : null,
  scopes: ['email', 'profile'],
);

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<void> forgotPassword(String email) async {
    await apiClient.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('구글 로그인이 취소되었습니다');

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Google ID 토큰을 가져오지 못했습니다');

      final res = await apiClient.dio.post('/auth/google', data: {'id_token': idToken});
      final token = res.data['access_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await fetchMe();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await apiClient.dio.post('/auth/register', data: {
        'email': email,
        'username': username,
        'password': password,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      });
      await login(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await apiClient.dio.post(
        '/auth/login',
        data: 'username=$email&password=$password',
        options: Options(headers: {'Content-Type': 'application/x-www-form-urlencoded'}),
      );
      final token = res.data['access_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await fetchMe();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') == null) return;
    try {
      final res = await apiClient.dio.get('/users/me');
      _user = User.fromJson(res.data);
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    _user = null;
    notifyListeners();
  }
}
