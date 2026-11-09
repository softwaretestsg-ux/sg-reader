import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static const String _keyEulaAccepted = 'eula_accepted_v1';
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isEulaAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEulaAccepted) ?? false;
  }

  Future<void> setEulaAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEulaAccepted, value);
  }

  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAppLockEnabled) ?? false;
  }

  Future<void> setAppLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, value);
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
