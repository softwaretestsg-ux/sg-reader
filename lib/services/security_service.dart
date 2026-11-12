import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static const String _keyEulaAccepted = 'eula_accepted_v1';
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isEulaAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      return prefs.getBool(_keyEulaAccepted) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEulaAccepted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs.setBool(_keyEulaAccepted, value);
    } catch (_) {}
  }

  Future<bool> isAppLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      return prefs.getBool(_keyAppLockEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAppLockEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs.setBool(_keyAppLockEnabled, value);
    } catch (_) {}
  }

  Future<bool> authenticateUser() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!isAvailable) return true; // If device has no biometrics, allow access

      return await _localAuth.authenticate(
        localizedReason: "Social Googol SG Reader: Authenticate to access your secure documents",
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      // In case of hardware auth exception, fail securely
      return false;
    }
  }
}
