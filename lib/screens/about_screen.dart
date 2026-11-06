import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/branding.dart';
import '../constants/legal_terms.dart';
import '../constants/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: const Text("About Social Googol", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Company Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SGTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SGTheme.borderStrong),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SGTheme.logoTileDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SGTheme.accentBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo-sg.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    BrandConstants.developerName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: SGTheme.text,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    BrandConstants.fullTagline,
                    style: TextStyle(
                      color: SGTheme.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "SG Reader is an enterprise-grade, air-gapped document viewer and editor designed for complete data privacy and security.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SGTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Connect Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SGTheme.surfaceHover,
                      foregroundColor: SGTheme.text,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: SGTheme.borderStrong),
                      ),
                    ),
                    icon: const Icon(Icons.phone_outlined, color: SGTheme.accent, size: 20),
                    label: const Text("Call Helpline"),
                    onPressed: () => _launch("tel:${BrandConstants.contactPhone}"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SGTheme.accentDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                    label: const Text("WhatsApp", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _launch(BrandConstants.contactWhatsAppUrl),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SGTheme.surface,
                foregroundColor: SGTheme.text,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: SGTheme.border),
                ),
              ),
              icon: const Icon(Icons.language_outlined, color: SGTheme.accent, size: 20),
              label: const Text("Visit www.socialgoogol.com"),
              onPressed: () => _launch(BrandConstants.websiteUrl),
            ),

            const SizedBox(height: 24),

            // Legal & Disclaimer Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SGTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SGTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Legal Notice & Limitation of Liability",
                    style: TextStyle(
                      color: SGTheme.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    LegalTerms.disclaimerSummary,
                    style: TextStyle(
                      color: SGTheme.textMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "SG Reader • Version: ${BrandConstants.fullVersionDisplay}\nAir-Gapped Local Architecture • Zero External Telemetry",
              textAlign: TextAlign.center,
              style: TextStyle(color: SGTheme.textMuted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
