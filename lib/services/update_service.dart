import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/branding.dart';

class UpdateInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static int get currentVersionCode => BrandConstants.buildNumber;
  static const String versionCheckUrl = "https://www.socialgoogol.com/app/version.json";

  /// Checks Social Googol server for newer APK version
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse(versionCheckUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final map = jsonDecode(body);
        final latestCode = map['version_code'] as int;

        if (latestCode > currentVersionCode) {
          return UpdateInfo(
            latestVersionCode: latestCode,
            latestVersionName: map['version_name'] ?? 'New Release',
            downloadUrl: map['download_url'] ?? BrandConstants.websiteUrl,
            releaseNotes: map['release_notes'] ?? 'General security & performance updates.',
          );
        }
      }
    } catch (_) {
      // Offline or network error - silently skip update check
    }
    return null;
  }

  /// Shows update prompt dialog to user
  static void showUpdateDialog(BuildContext context, UpdateInfo update) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.system_update, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("Update Available"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Version ${update.latestVersionName} is now available with the latest security enhancements."),
            const SizedBox(height: 12),
            Text("What's new:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(update.releaseNotes, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Later"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F9D58)),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(update.downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("Download APK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
