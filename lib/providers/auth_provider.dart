import 'dart:convert';
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

    // Load saved local profile if any
    final savedAvatar = prefs.getString('local_avatar_url');
    final savedName = prefs.getString('local_full_name');
    final savedUsername = prefs.getString('local_username');
    final savedAbout = prefs.getString('local_about');

    _currentUser = _currentUser.copyWith(
      fullName: savedName ?? _currentUser.fullName,
      username: savedUsername ?? _currentUser.username,
      about: savedAbout ?? _currentUser.about,
      avatarUrl: savedAvatar ?? _currentUser.avatarUrl,
    );

    if (connected && _supabaseService.isAuthenticated) {
      final user = _supabaseService.currentAuthUser;
      if (user != null) {
        final profile = await _supabaseService.fetchProfile(user.id);
        if (profile != null) {
          _currentUser = profile.copyWith(
            avatarUrl: savedAvatar ?? profile.avatarUrl ?? _currentUser.avatarUrl,
          );
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
    final prefs = await SharedPreferences.getInstance();
    final savedAvatar = prefs.getString('local_avatar_url');
    final savedName = prefs.getString('local_full_name');
    final savedUsername = prefs.getString('local_username');
    final savedAbout = prefs.getString('local_about');

    _currentUser = MockData.currentUser.copyWith(
      fullName: savedName ?? MockData.currentUser.fullName,
      username: savedUsername ?? MockData.currentUser.username,
      about: savedAbout ?? MockData.currentUser.about,
      avatarUrl: savedAvatar ?? MockData.currentUser.avatarUrl,
    );
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
    bool deleteExistingAvatar = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    String? finalAvatar = deleteExistingAvatar ? null : (avatarUrl ?? _currentUser.avatarUrl);

    if (newAvatarBytes != null && !deleteExistingAvatar) {
      if (_isSupabaseConnected) {
        final fileName = 'avatar_${_currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedUrl = await _supabaseService.uploadFile(
          bucketName: 'avatars',
          filePath: fileName,
          fileBytes: newAvatarBytes,
          contentType: 'image/jpeg',
        );
        if (uploadedUrl != null) {
          finalAvatar = uploadedUrl;
        } else {
          finalAvatar = 'data:image/jpeg;base64,${base64Encode(newAvatarBytes)}';
        }
      } else {
        // Local base64 data URI for demo / offline mode
        finalAvatar = 'data:image/jpeg;base64,${base64Encode(newAvatarBytes)}';
      }
    }

    _currentUser = UserProfile(
      id: _currentUser.id,
      username: username,
      fullName: fullName,
      avatarUrl: finalAvatar,
      about: about,
      role: _currentUser.role,
      isOnline: _currentUser.isOnline,
      lastSeen: _currentUser.lastSeen,
    );

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_full_name', fullName);
    await prefs.setString('local_username', username);
    await prefs.setString('local_about', about);
    if (finalAvatar != null) {
      await prefs.setString('local_avatar_url', finalAvatar);
    } else {
      await prefs.remove('local_avatar_url');
    }

    if (_isSupabaseConnected) {
      await _supabaseService.updateProfile(_currentUser);
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> deleteAvatar() async {
    await updateProfile(
      fullName: _currentUser.fullName,
      username: _currentUser.username,
      about: _currentUser.about,
      deleteExistingAvatar: true,
    );
  }

  Future<void> toggleBiometric(bool value) async {
    _biometricEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
  }
}

