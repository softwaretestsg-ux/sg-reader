import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: SGTheme.surface,
        border: Border(
          bottom: BorderSide(color: SGTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Official Social Googol Logo Tile
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: SGTheme.logoTileDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SGTheme.borderStrong, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo-sg.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield_outlined,
                  color: SGTheme.accent,
                  size: 22,
                ),
              ),
            ),
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
                    color: SGTheme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  BrandConstants.fullTagline,
                  style: TextStyle(
                    color: SGTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Actions: Direct Phone & Official Website
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined, color: SGTheme.textSecondary, size: 20),
            tooltip: "Call Support (${BrandConstants.contactPhoneFormatted})",
            onPressed: () => _launchUrl("tel:${BrandConstants.contactPhone}"),
          ),
          IconButton(
            icon: const Icon(Icons.language_outlined, color: SGTheme.textSecondary, size: 20),
            tooltip: "Visit Website",
            onPressed: () => _launchUrl(BrandConstants.websiteUrl),
          ),
        ],
      ),
    );
  }
}
