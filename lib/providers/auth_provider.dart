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
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _biometricEnabled = true;
  String? _errorMessage;
  bool _isSupabaseConnected = false;

  UserProfile get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
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
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // Load saved local profile if any
    final savedAvatar = prefs.getString('local_avatar_url');
    final savedName = prefs.getString('local_full_name');
    final savedUsername = prefs.getString('local_username');
    final savedAbout = prefs.getString('local_about');

    // Clean out any old mock template bot usernames from registered_users_db
    try {
      final dbJson = prefs.getString('registered_users_db') ?? '{}';
      final Map<String, dynamic> db = jsonDecode(dbJson);
      const mockBots = [
        'lola_k', 'abbos_sh', 'aziz_dev', 'dilnoza_ui', 'sardor_pm',
        'elena_r', 'david_c', 'anna_s', 'sarah_m', 'michael_b'
      ];
      bool cleaned = false;
      for (final bot in mockBots) {
        if (db.containsKey(bot)) {
          db.remove(bot);
          cleaned = true;
          prefs.remove('user_${bot}_full_name');
          prefs.remove('user_${bot}_about');
          prefs.remove('user_${bot}_avatar_url');
        }
      }
      if (cleaned) {
        await prefs.setString('registered_users_db', jsonEncode(db));
      }
    } catch (e) {
      debugPrint('Error cleaning mock bots: $e');
    }

    if (savedUsername != null) {
      final userAbout = prefs.getString('user_${savedUsername}_about') ?? savedAbout;
      final userAvatar = prefs.getString('user_${savedUsername}_avatar_url') ?? savedAvatar;
      final userName = prefs.getString('user_${savedUsername}_full_name') ?? savedName;

      _currentUser = UserProfile(
        id: 'user-$savedUsername',
        username: savedUsername,
        fullName: userName ?? savedUsername,
        about: userAbout ?? _currentUser.about,
        avatarUrl: userAvatar,
      );
    }

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

  Future<bool> loginByUsername(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanUsername = username.trim().toLowerCase();

    try {
      if (_isSupabaseConnected) {
        // Query Supabase profiles table for existing user
        final profile = await _supabaseService.fetchProfileByUsername(cleanUsername);
        if (profile == null) {
          _errorMessage = "Ushbu username ('$cleanUsername') bazada topilmadi! Avval Ro'yxatdan o'tish bo'limidan yangi hisob yarating.";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final email = '$cleanUsername@supachat.local';
        final response = await _supabaseService.signInWithEmail(email, password);
        if (response?.user != null) {
          _currentUser = profile;
        } else {
          // If auth signin fails, load profile directly if password matched in local credentials
          final prefs = await SharedPreferences.getInstance();
          final dbJson = prefs.getString('registered_users_db') ?? '{}';
          final Map<String, dynamic> db = jsonDecode(dbJson);
          if (db.containsKey(cleanUsername) && db[cleanUsername] != password) {
            _errorMessage = "Parol noto'g'ri kiritildi! Qayta urinib ko'ring.";
            _isLoading = false;
            notifyListeners();
            return false;
          }
          _currentUser = profile;
        }
      } else {
        // Strict Local Database credentials check
        await Future.delayed(const Duration(milliseconds: 400));
        final prefs = await SharedPreferences.getInstance();
        final dbJson = prefs.getString('registered_users_db') ?? '{}';
        final Map<String, dynamic> db = jsonDecode(dbJson);

        if (!db.containsKey(cleanUsername)) {
          _errorMessage = "Ushbu username ('$cleanUsername') bazada topilmadi! Avval Ro'yxatdan o'tish bo'limida yangi hisob yarating.";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (db[cleanUsername] != password) {
          _errorMessage = "Parol noto'g'ri kiritildi! Qayta urinib ko'ring.";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final savedName = prefs.getString('user_${cleanUsername}_full_name');
        final savedAbout = prefs.getString('user_${cleanUsername}_about');
        final savedAvatar = prefs.getString('user_${cleanUsername}_avatar_url');

        _currentUser = UserProfile(
          id: 'user-$cleanUsername',
          username: cleanUsername,
          fullName: savedName ?? username.trim(),
          about: savedAbout ?? 'Hey there! I am using SupaChat.',
          avatarUrl: savedAvatar,
        );
      }

      _isLoggedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('local_username', cleanUsername);
      await prefs.setString('local_full_name', _currentUser.fullName);
      await prefs.setString('local_about', _currentUser.about);
      if (_currentUser.avatarUrl != null) {
        await prefs.setString('local_avatar_url', _currentUser.avatarUrl!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Kirishda xatolik yuz berdi: ${e.toString()}";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> registerByUsername({
    required String username,
    required String fullName,
    required String about,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanUsername = username.trim().toLowerCase();

    try {
      final prefs = await SharedPreferences.getInstance();
      final dbJson = prefs.getString('registered_users_db') ?? '{}';
      final Map<String, dynamic> db = jsonDecode(dbJson);

      // 1. Check if username exists in local database
      if (db.containsKey(cleanUsername)) {
        _errorMessage = "Ushbu username ('$cleanUsername') allaqachon ro'yxatdan o'tgan! Boshqa username tanlang yoki Kirish bo'limidan kiring.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_isSupabaseConnected) {
        // 2. Check if username exists in Supabase database
        final existingProfile = await _supabaseService.fetchProfileByUsername(cleanUsername);
        if (existingProfile != null) {
          _errorMessage = "Ushbu username ('$cleanUsername') Supabase bazasida allaqachon ro'yxatdan o'tgan! Boshqa username tanlang.";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final email = '$cleanUsername@supachat.local';
        final response = await _supabaseService.signUpWithEmail(
          email,
          password,
          username: cleanUsername,
          fullName: fullName,
        );
        final userId = response?.user?.id ?? 'user-$cleanUsername';
        _currentUser = UserProfile(
          id: userId,
          username: cleanUsername,
          fullName: fullName,
          about: about.isNotEmpty ? about : 'Hey there! I am using SupaChat.',
        );
        await _supabaseService.updateProfile(_currentUser);
      } else {
        // Local Registration Mode
        await Future.delayed(const Duration(milliseconds: 400));
        _currentUser = UserProfile(
          id: 'user-$cleanUsername',
          username: cleanUsername,
          fullName: fullName.isNotEmpty ? fullName : cleanUsername,
          about: about.isNotEmpty ? about : 'Hey there! I am using SupaChat.',
        );
      }

      // Save credentials into persistent user database
      db[cleanUsername] = password;
      await prefs.setString('registered_users_db', jsonEncode(db));

      // Persist active session
      _isLoggedIn = true;
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('local_username', cleanUsername);
      await prefs.setString('local_full_name', _currentUser.fullName);
      await prefs.setString('local_about', _currentUser.about);
      await prefs.setString('user_${cleanUsername}_full_name', _currentUser.fullName);
      await prefs.setString('user_${cleanUsername}_about', _currentUser.about);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Ro'yxatdan o'tishda xatolik: ${e.toString()}";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (_isSupabaseConnected) {
      await _supabaseService.signOut();
    }
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

    // Save to SharedPreferences per username & globally
    final cleanUser = username.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_full_name', fullName);
    await prefs.setString('local_username', cleanUser);
    await prefs.setString('local_about', about);
    await prefs.setString('user_${cleanUser}_full_name', fullName);
    await prefs.setString('user_${cleanUser}_about', about);
    if (finalAvatar != null) {
      await prefs.setString('local_avatar_url', finalAvatar);
      await prefs.setString('user_${cleanUser}_avatar_url', finalAvatar);
    } else {
      await prefs.remove('local_avatar_url');
      await prefs.remove('user_${cleanUser}_avatar_url');
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

