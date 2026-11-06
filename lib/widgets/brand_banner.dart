import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';

class BrandBanner extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onOpenDrawer;
  const BrandBanner({Key? key, this.onOpenDrawer}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(80);

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SGTheme.surface,
        border: Border(
          bottom: BorderSide(color: SGTheme.border, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Drawer menu launcher
              IconButton(
                icon: const Icon(Icons.menu, color: SGTheme.textSecondary, size: 22),
                tooltip: "Menu & Disclaimer",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (onOpenDrawer != null) {
                    onOpenDrawer!();
                  } else {
                    Scaffold.maybeOf(context)?.openDrawer();
                  }
                },
              ),
              const SizedBox(width: 10),
              // Official Social Googol Logo Tile
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SGTheme.logoTileDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SGTheme.borderStrong, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/logo-sg.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_outlined,
                      color: SGTheme.accent,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Developer Name & Hindi Tagline
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
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      BrandConstants.taglineHindi,
                      style: TextStyle(
                        color: SGTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
