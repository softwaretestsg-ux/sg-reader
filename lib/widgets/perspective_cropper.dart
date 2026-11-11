import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/scanner_service.dart';

class PerspectiveCropperScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final QuadCorners initialCorners;

  const PerspectiveCropperScreen({
    Key? key,
    required this.imageBytes,
    this.initialCorners = QuadCorners.defaultNormalized,
  }) : super(key: key);

  @override
  State<PerspectiveCropperScreen> createState() => _PerspectiveCropperScreenState();
}

class _PerspectiveCropperScreenState extends State<PerspectiveCropperScreen> {
  final ScannerService _scannerService = ScannerService();
  late Offset _tl;
  late Offset _tr;
  late Offset _br;
  late Offset _bl;
  int? _activeCornerIndex; // 0: TL, 1: TR, 2: BR, 3: BL
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tl = widget.initialCorners.topLeft;
    _tr = widget.initialCorners.topRight;
    _br = widget.initialCorners.bottomRight;
    _bl = widget.initialCorners.bottomLeft;
  }

  void _resetCorners() {
    setState(() {
      _tl = QuadCorners.defaultNormalized.topLeft;
      _tr = QuadCorners.defaultNormalized.topRight;
      _br = QuadCorners.defaultNormalized.bottomRight;
      _bl = QuadCorners.defaultNormalized.bottomLeft;
    });
  }

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);
    try {
      final corners = QuadCorners(
        topLeft: _tl,
        topRight: _tr,
        bottomRight: _br,
        bottomLeft: _bl,
      );
      final cropped = await _scannerService.cropPerspective(widget.imageBytes, corners);
      if (mounted) {
        Navigator.pop(context, cropped);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cropping error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: const Text(
          "Adjust Document Corners",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SGTheme.text),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.refresh, color: SGTheme.accent, size: 18),
            label: const Text("Reset", style: TextStyle(color: SGTheme.accent, fontSize: 13)),
            onPressed: _resetCorners,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final boxW = constraints.maxWidth;
          final boxH = constraints.maxHeight - 80;

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    width: boxW,
                    height: boxH,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Interactive Cropping Mesh Overlay
                        Positioned.fill(
                          child: GestureDetector(
                            onPanDown: (details) => _onPanDown(details.localPosition, boxW, boxH),
                            onPanUpdate: (details) => _onPanUpdate(details.localPosition, boxW, boxH),
                            onPanEnd: (_) => setState(() => _activeCornerIndex = null),
                            child: CustomPaint(
                              painter: _QuadMeshPainter(
                                tl: _tl,
                                tr: _tr,
                                br: _br,
                                bl: _bl,
                                activeIndex: _activeCornerIndex,
                              ),
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: CircularProgressIndicator(color: SGTheme.accent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                color: SGTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SGTheme.textSecondary,
                          side: BorderSide(color: SGTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(context, widget.imageBytes),
                        child: const Text("Skip Cropping"),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.styleFrom(
                        backgroundColor: SGTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ).build(
                        context: context,
                        onPressed: _isProcessing ? null : _applyCrop,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.crop_outlined, size: 20),
                            SizedBox(width: 8),
                            Text("Dewarp & Continue", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPanDown(Offset local, double w, double h) {
    final normTouch = Offset(local.dx / w, local.dy / h);
    final corners = [_tl, _tr, _br, _bl];
    int closest = 0;
    double minD = (normTouch - corners[0]).distance;

    for (int i = 1; i < 4; i++) {
      final d = (normTouch - corners[i]).distance;
      if (d < minD) {
        minD = d;
        closest = i;
      }
    }

    if (minD < 0.20) {
      setState(() => _activeCornerIndex = closest);
    }
  }

  void _onPanUpdate(Offset local, double w, double h) {
    if (_activeCornerIndex == null) return;
    final clamped = Offset(
      (local.dx / w).clamp(0.01, 0.99),
      (local.dy / h).clamp(0.01, 0.99),
    );

    setState(() {
      switch (_activeCornerIndex!) {
        case 0:
          _tl = clamped;
          break;
        case 1:
          _tr = clamped;
          break;
        case 2:
          _br = clamped;
          break;
        case 3:
          _bl = clamped;
          break;
      }
    });
  }
}

class _QuadMeshPainter extends CustomPainter {
  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;
  final int? activeIndex;

  _QuadMeshPainter({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
    this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pTL = Offset(tl.dx * size.width, tl.dy * size.height);
    final pTR = Offset(tr.dx * size.width, tr.dy * size.height);
    final pBR = Offset(br.dx * size.width, br.dy * size.height);
    final pBL = Offset(bl.dx * size.width, bl.dy * size.height);

    // 1. Shaded Background Outside Polygon
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPolygon([pTL, pTR, pBR, pBL], true)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      bgPath,
      Paint()..color = Colors.black.withOpacity(0.40),
    );

    // 2. Connecting Border Lines
    final borderPaint = Paint()
      ..color = SGTheme.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final polyPath = Path()
      ..moveTo(pTL.dx, pTL.dy)
      ..lineTo(pTR.dx, pTR.dy)
      ..lineTo(pBR.dx, pBR.dy)
      ..lineTo(pBL.dx, pBL.dy)
      ..close();

    canvas.drawPath(polyPath, borderPaint);

    // 3. Grid guide lines
    final gridPaint = Paint()
      ..color = SGTheme.accent.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontal thirds
    for (double f in [0.33, 0.66]) {
      final p1 = Offset.lerp(pTL, pBL, f)!;
      final p2 = Offset.lerp(pTR, pBR, f)!;
      canvas.drawLine(p1, p2, gridPaint);
    }
    // Vertical thirds
    for (double f in [0.33, 0.66]) {
      final p1 = Offset.lerp(pTL, pTR, f)!;
      final p2 = Offset.lerp(pBL, pBR, f)!;
      canvas.drawLine(p1, p2, gridPaint);
    }

    // 4. Corner Handles
    final points = [pTL, pTR, pBR, pBL];
    for (int i = 0; i < points.length; i++) {
      final isActive = i == activeIndex;
      final radius = isActive ? 16.0 : 12.0;

      // Outer glow / border
      canvas.drawCircle(
        points[i],
        radius + 2,
        Paint()..color = Colors.white,
      );
      // Inner terracotta circle
      canvas.drawCircle(
        points[i],
        radius,
        Paint()..color = SGTheme.accent,
      );
      // Center pin
      canvas.drawCircle(
        points[i],
        4.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuadMeshPainter oldDelegate) {
    return oldDelegate.tl != tl ||
        oldDelegate.tr != tr ||
        oldDelegate.br != br ||
        oldDelegate.bl != bl ||
        oldDelegate.activeIndex != activeIndex;
  }
}
