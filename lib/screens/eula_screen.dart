import 'package:flutter/material.dart';
import '../constants/branding.dart';
import '../constants/legal_terms.dart';
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          "Terms & Legal Disclaimer",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.2),
                  border: Border.all(color: Colors.amber.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: Colors.amberAccent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Please read and accept the terms of use provided by Social Googol before using SG Reader.",
                        style: TextStyle(color: Colors.white, fontSize: 12),
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
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      LegalTerms.fullTerms,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Checkbox acceptance
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  activeColor: const Color(0xFF10B981),
                  title: const Text(
                    "I have read, understood, and accept the 'AS-IS' terms and limitation of liability.",
                    style: TextStyle(color: Colors.white, fontSize: 12),
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
                  backgroundColor: _accepted ? const Color(0xFF10B981) : Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _accepted ? _onProceed : null,
                child: const Text(
                  "I Agree & Continue",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
