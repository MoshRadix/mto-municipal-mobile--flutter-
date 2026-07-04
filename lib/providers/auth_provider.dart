import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;

  User? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;

  AuthProvider({required this._apiService}) {
    checkAuthStatus();
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  // Restore session from cache
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final cachedUser = await _apiService.getCachedUser();
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _isAuthenticated = true;
        notifyListeners();

        // Silently verify session on server to make sure cookie hasn't expired
        try {
          final verifiedUser = await _apiService.fetchProfile();
          _currentUser = verifiedUser;
        } catch (e) {
          debugPrint('Cached session expired: $e');
          // Session expired, log out silently
          await logout();
        }
      }
    } catch (e) {
      debugPrint('Check auth status error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _apiService.login(email, password);
      _currentUser = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.clearSession();
    } catch (e) {
      debugPrint('Logout API clear error: $e');
    }

    _currentUser = null;
    _isAuthenticated = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
