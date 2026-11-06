import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/branding.dart';

class BrandBanner extends StatelessWidget {
  const BrandBanner({Key? key}) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Premium slate dark
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Company Icon / Logo Badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          // Titles & Taglines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  BrandConstants.developerName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  BrandConstants.fullTagline,
                  style: TextStyle(
                    color: Color(0xFF34D399), // Emerald
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons: Call & WhatsApp
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Colors.white70, size: 20),
            tooltip: "Call Support (${BrandConstants.contactPhoneFormatted})",
            onPressed: () => _launchUrl("tel:${BrandConstants.contactPhone}"),
          ),
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white70, size: 20),
            tooltip: "Visit Website",
            onPressed: () => _launchUrl(BrandConstants.websiteUrl),
          ),
        ],
      ),
    );
  }
}
