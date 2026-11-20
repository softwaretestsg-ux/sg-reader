import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/theme.dart';

class _DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  _DrawingStroke({required this.points, required this.color, required this.strokeWidth});
}

class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({Key? key}) : super(key: key);

  static Future<Uint8List?> show(BuildContext context) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const SignaturePadDialog(),
    );
  }

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<_DrawingStroke> _strokes = [];
  _DrawingStroke? _currentStroke;
  Color _selectedColor = const Color(0xFF003399); // Legal Blue
  double _strokeWidth = 3.0;

  final List<Color> _inkColors = [
    const Color(0xFF003399), // Royal / Legal Blue
    const Color(0xFF111111), // Formal Black
    const Color(0xFFC43E1C), // Stamp Crimson
    const Color(0xFF107C41), // Verified Green
  ];

  Future<Uint8List?> _renderSignatureToPng() async {
    if (_strokes.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const canvasSize = Size(600, 300);

    // Render strokes on transparent canvas
    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth * 1.5
        ..style = PaintingStyle.stroke;

      if (stroke.points.length > 1) {
        final path = Path();
        path.moveTo(stroke.points.first.dx * (600 / 300), stroke.points.first.dy * (300 / 180));
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx * (600 / 300), stroke.points[i].dy * (300 / 180));
        }
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(600, 300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.draw, color: Color(0xFF003399), size: 24),
              SizedBox(width: 8),
              Text(
                "Digital Signature (Fill & Sign)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF242424)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Draw your signature with your finger. It will be stamped transparently onto your document.",
              style: TextStyle(fontSize: 12, color: Color(0xFF605E5C)),
            ),
            const SizedBox(height: 12),

            // Drawing Canvas Card
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D1D1), width: 1.5),
              ),
              child: Stack(
                children: [
                  // Signature baseline indicator
                  Positioned(
                    bottom: 34,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: Text(
                      "Sign on the line ✕",
                      style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.6), fontStyle: FontStyle.italic),
                    ),
                  ),

                  // Gesture detector for drawing strokes
                  GestureDetector(
                    onPanStart: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      final local = details.localPosition;
                      setState(() {
                        _currentStroke = _DrawingStroke(
                          points: [local],
                          color: _selectedColor,
                          strokeWidth: _strokeWidth,
                        );
                        _strokes.add(_currentStroke!);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentStroke?.points.add(details.localPosition);
                      });
                    },
                    onPanEnd: (_) {
                      _currentStroke = null;
                    },
                    child: CustomPaint(
                      painter: _SignaturePainter(strokes: _strokes),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Controls Bar: Colors & Stroke Width
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: _inkColors.map((c) {
                    final isSelected = c == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.white,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(color: c.withOpacity(0.4), blurRadius: 4, spreadRadius: 1),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC43E1C)),
                  label: const Text("Clear", style: TextStyle(fontSize: 12, color: Color(0xFFC43E1C))),
                  onPressed: () {
                    setState(() => _strokes.clear());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Color(0xFF605E5C))),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003399),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: const Icon(Icons.check, size: 18, color: Colors.white),
          label: const Text("Adopt & Stamp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () async {
            if (_strokes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please draw your signature before adopting.")),
              );
              return;
            }
            final pngBytes = await _renderSignatureToPng();
            if (context.mounted) {
              Navigator.pop(context, pngBytes);
            }
          },
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<_DrawingStroke> strokes;

  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;

      if (stroke.points.length > 1) {
        final path = Path();
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
