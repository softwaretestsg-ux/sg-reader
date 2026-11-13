import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keyEulaAccepted = 'eula_accepted_v1';

  Future<File?> _getFlagFile(String filename) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return File('${appDir.path}/$filename');
    } catch (_) {
      return null;
    }
  }

  /// Checks if EULA has been accepted by user.
  /// Dual-layer persistence: Checks local persistent disk file first,
  /// then falls back to SharedPreferences for zero-failure reliability.
  Future<bool> isEulaAccepted() async {
    // 1. Instant local disk file check
    try {
      final file = await _getFlagFile('.sg_eula_accepted_v1');
      if (file != null && await file.exists()) {
        return true;
      }
    } catch (_) {}

    // 2. SharedPreferences check
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 4),
      );
      final accepted = prefs.getBool(_keyEulaAccepted) ?? false;
      if (accepted) {
        // Self-heal: Ensure disk file is written for next time
        try {
          final file = await _getFlagFile('.sg_eula_accepted_v1');
          if (file != null && !await file.exists()) {
            await file.writeAsString("accepted", flush: true);
          }
        } catch (_) {}
      }
      return accepted;
    } catch (e) {
      debugPrint("Error reading EULA state: $e");
      return false;
    }
  }

  /// Persists EULA acceptance permanently to both local disk file and SharedPreferences.
  Future<void> setEulaAccepted(bool value) async {
    // 1. Write local disk file
    try {
      final file = await _getFlagFile('.sg_eula_accepted_v1');
      if (file != null) {
        if (value) {
          await file.writeAsString("accepted", flush: true);
        } else if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint("Error writing EULA file: $e");
    }

    // 2. Write SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 4),
      );
      await prefs.setBool(_keyEulaAccepted, value);
    } catch (e) {
      debugPrint("Error saving EULA preference: $e");
    }
  }
}
