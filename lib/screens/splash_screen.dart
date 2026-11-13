import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';
import '../services/security_service.dart';
import 'eula_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final SecurityService _securityService = SecurityService();
  bool _hasNavigated = false;
  bool _showManualContinue = false;
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Safety Watchdog: If navigation has not occurred after 2.5 seconds,
    // show manual enter button so the user is never stuck.
    _watchdogTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_hasNavigated) {
        setState(() {
          _showManualContinue = true;
        });
      }
    });

    _navigateNext();
  }

  void _safeNavigate(Widget target) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _watchdogTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  Future<void> _navigateNext() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted || _hasNavigated) return;

      // Check EULA status safely with timeout
      bool isEulaAccepted = false;
      try {
        isEulaAccepted = await _securityService.isEulaAccepted().timeout(
          const Duration(seconds: 3),
          onTimeout: () => true, // Fallback to true if previously initialized
        );
      } catch (e) {
        debugPrint("EULA check exception: $e");
        isEulaAccepted = false;
      }

      if (!mounted || _hasNavigated) return;

      if (!isEulaAccepted) {
        _safeNavigate(const EulaScreen());
        return;
      }

      _safeNavigate(const HomeScreen());
    } catch (e, stack) {
      debugPrint("Startup navigation error: $e\n$stack");
      _safeNavigate(const HomeScreen());
    }
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Official Social Googol Logo Card
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SGTheme.logoTileDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: SGTheme.accentBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: SGTheme.accent.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo-sg.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_outlined,
                      size: 50,
                      color: SGTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Brand & App Name
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "Social Googol's\n",
                      style: TextStyle(
                        fontSize: 15,
                        color: SGTheme.textSecondary,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: "SG Reader",
                      style: TextStyle(
                        fontSize: 32,
                        color: SGTheme.text,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tagline (Bilingual)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: SGTheme.surfaceHover,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SGTheme.borderStrong),
                ),
                child: const Text(
                  BrandConstants.fullTagline,
                  style: TextStyle(
                    color: SGTheme.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              if (_showManualContinue) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SGTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text("Enter SG Reader", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _safeNavigate(const HomeScreen()),
                ),
              ] else ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(SGTheme.accent),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Prominent Version Indicator on Initial Loading Page
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: SGTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SGTheme.accentBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified_outlined, color: SGTheme.accent, size: 14),
                    SizedBox(width: 6),
                    Text(
                      BrandConstants.fullVersionDisplay,
                      style: TextStyle(
                        color: SGTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Social Googol • Secure to Grow",
                style: TextStyle(
                  color: SGTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "100% Offline Sandbox • Air-Gapped Privacy",
                style: TextStyle(
                  color: SGTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
