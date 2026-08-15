import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/mock_data.dart';
import '../data/models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  UserProfile _currentUser = MockData.currentUser;
  bool _isLoading = false;
  bool _biometricEnabled = true;
  String? _errorMessage;
  bool _isSupabaseConnected = false;

  UserProfile get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get biometricEnabled => _biometricEnabled;
  String? get errorMessage => _errorMessage;
  bool get isSupabaseConnected => _isSupabaseConnected;
  SupabaseService get supabaseService => _supabaseService;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _isLoading = true;
    notifyListeners();

    final connected = await _supabaseService.initialize();
    _isSupabaseConnected = connected;

    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled = prefs.getBool('biometric_enabled') ?? true;

    if (connected && _supabaseService.isAuthenticated) {
      final user = _supabaseService.currentAuthUser;
      if (user != null) {
        final profile = await _supabaseService.fetchProfile(user.id);
        if (profile != null) {
          _currentUser = profile;
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> connectSupabase(String url, String anonKey) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final success = await _supabaseService.connect(url, anonKey);
    _isSupabaseConnected = success;
    if (!success) {
      _errorMessage = "Supabase serveriga ulanib bo'lmadi. URL va Anon Keyni tekshiring.";
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> disconnectSupabase() async {
    await _supabaseService.disconnect();
    _isSupabaseConnected = false;
    _currentUser = MockData.currentUser;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isSupabaseConnected) {
        final response = await _supabaseService.signInWithEmail(email, password);
        if (response?.user != null) {
          final profile = await _supabaseService.fetchProfile(response!.user!.id);
          if (profile != null) {
            _currentUser = profile;
          } else {
            _currentUser = UserProfile(
              id: response.user!.id,
              username: email.split('@').first,
              fullName: email.split('@').first,
            );
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        // Demo login mode
        await Future.delayed(const Duration(milliseconds: 600));
        _currentUser = _currentUser.copyWith(
          username: email.split('@').first,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile({
    required String fullName,
    required String username,
    required String about,
    String? avatarUrl,
    Uint8List? newAvatarBytes,
  }) async {
    _isLoading = true;
    notifyListeners();

    String finalAvatar = avatarUrl ?? _currentUser.avatarUrl ?? '';

    if (newAvatarBytes != null && _isSupabaseConnected) {
      final fileName = 'avatar_${_currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadedUrl = await _supabaseService.uploadFile(
        bucketName: 'avatars',
        filePath: fileName,
        fileBytes: newAvatarBytes,
        contentType: 'image/jpeg',
      );
      if (uploadedUrl != null) {
        finalAvatar = uploadedUrl;
      }
    }

    _currentUser = _currentUser.copyWith(
      fullName: fullName,
      username: username,
      about: about,
      avatarUrl: finalAvatar.isNotEmpty ? finalAvatar : null,
    );

    if (_isSupabaseConnected) {
      await _supabaseService.updateProfile(_currentUser);
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> toggleBiometric(bool value) async {
    _biometricEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
  }
}
