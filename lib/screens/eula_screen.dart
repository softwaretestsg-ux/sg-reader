import 'package:flutter/material.dart';
import '../constants/branding.dart';
import '../constants/legal_terms.dart';
import '../constants/theme.dart';
import '../services/security_service.dart';
import 'home_screen.dart';

class EulaScreen extends StatefulWidget {
  const EulaScreen({Key? key}) : super(key: key);

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _accepted = false;
  final SecurityService _securityService = SecurityService();

  Future<void> _onProceed() async {
    if (!_accepted) return;
    await _securityService.setEulaAccepted(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        elevation: 0,
        title: const Text(
          "Terms & Legal Disclaimer",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Header Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SGTheme.surface,
                  border: Border.all(color: SGTheme.accentBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: SGTheme.accent, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Please review and accept the terms of use provided by Social Googol before using SG Reader.",
                        style: TextStyle(color: SGTheme.textSecondary, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Scrollable Legal Text Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SGTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SGTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      LegalTerms.fullTerms,
                      style: const TextStyle(
                        color: SGTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Checkbox acceptance
              Container(
                decoration: BoxDecoration(
                  color: SGTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SGTheme.border),
                ),
                child: CheckboxListTile(
                  activeColor: SGTheme.accentDeep,
                  title: const Text(
                    "I have read, understood, and accept the 'AS-IS' terms and limitation of liability.",
                    style: TextStyle(color: SGTheme.text, fontSize: 12),
                  ),
                  value: _accepted,
                  onChanged: (val) {
                    setState(() {
                      _accepted = val ?? false;
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Action button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accepted ? SGTheme.accentDeep : SGTheme.surfaceHover,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _accepted ? _onProceed : null,
                child: const Text(
                  "I Agree & Continue",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
