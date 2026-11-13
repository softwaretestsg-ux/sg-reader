import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Professional Floating Zoom Dock for Document Pages
/// Supports + / - buttons, live percentage display, and tap-to-reset.
/// Features subtle auto-fade to prevent obstructing document text during reading.
class ZoomControlsDock extends StatefulWidget {
  final double currentZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final double minZoom;
  final double maxZoom;

  const ZoomControlsDock({
    Key? key,
    required this.currentZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.minZoom = 0.5,
    this.maxZoom = 5.0,
  }) : super(key: key);

  @override
  State<ZoomControlsDock> createState() => _ZoomControlsDockState();
}

class _ZoomControlsDockState extends State<ZoomControlsDock> {
  bool _isIdle = false;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _startFadeTimer();
  }

  @override
  void didUpdateWidget(covariant ZoomControlsDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentZoom != widget.currentZoom) {
      _wakeUp();
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _wakeUp() {
    if (_isIdle) {
      setState(() {
        _isIdle = false;
      });
    }
    _startFadeTimer();
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isIdle = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (widget.currentZoom * 100).round();
    final canZoomIn = widget.currentZoom < widget.maxZoom - 0.05;
    final canZoomOut = widget.currentZoom > widget.minZoom + 0.05;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _wakeUp,
      child: AnimatedOpacity(
        opacity: _isIdle ? 0.38 : 0.96,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            color: SGTheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SGTheme.accentBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom Out Button (−)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: canZoomOut
                      ? () {
                          _wakeUp();
                          widget.onZoomOut();
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(7.0),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 20,
                      color: canZoomOut ? SGTheme.text : SGTheme.textMuted.withOpacity(0.35),
                    ),
                  ),
                ),
              ),

              // Zoom Percentage / Reset Chip
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _wakeUp();
                    widget.onResetZoom();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SGTheme.bgDark.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SGTheme.border),
                    ),
                    child: Text(
                      "$zoomPercent%",
                      style: const TextStyle(
                        color: SGTheme.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),

              // Zoom In Button (+)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: canZoomIn
                      ? () {
                          _wakeUp();
                          widget.onZoomIn();
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(7.0),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: canZoomIn ? SGTheme.text : SGTheme.textMuted.withOpacity(0.35),
                    ),
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
