import 'package:flutter/material.dart';
import '../constants/branding.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 2200));

    final isEulaAccepted = await _securityService.isEulaAccepted();
    if (!mounted) return;

    if (!isEulaAccepted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EulaScreen()),
      );
      return;
    }

    final isLockEnabled = await _securityService.isAppLockEnabled();
    if (isLockEnabled) {
      final authenticated = await _securityService.authenticateUser();
      if (!authenticated) {
        // App closes or stays locked if user fails biometric check
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Shield Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "Social Googol's\n",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: "SG Reader",
                      style: TextStyle(
                        fontSize: 34,
                        color: Colors.white,
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
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  BrandConstants.fullTagline,
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 48),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
