import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/watermark_service.dart';

class WatermarkEraserDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const WatermarkEraserDialog({Key? key, required this.imageBytes}) : super(key: key);

  @override
  State<WatermarkEraserDialog> createState() => _WatermarkEraserDialogState();
}

class _WatermarkEraserDialogState extends State<WatermarkEraserDialog> {
  final WatermarkService _watermarkService = WatermarkService();
  late Uint8List _currentBytes;
  bool _isProcessing = false;
  WatermarkColorType _selectedColorType = WatermarkColorType.lightGray;

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.imageBytes;
  }

  Future<void> _applyColorStripper() async {
    setState(() => _isProcessing = true);
    try {
      final cleaned = await _watermarkService.removeColorWatermark(
        _currentBytes,
        type: _selectedColorType,
      );
      if (mounted) {
        setState(() {
          _currentBytes = cleaned;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Watermark color stripped successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _erasePresetArea(String preset) async {
    setState(() => _isProcessing = true);
    try {
      double l = 0, t = 0, w = 1.0, h = 0.08;
      if (preset == 'footer') {
        // Bottom 8% (common for "Scanned with ..." footers)
        t = 0.92;
        h = 0.08;
      } else if (preset == 'header') {
        // Top 8%
        t = 0.0;
        h = 0.08;
      } else if (preset == 'bottom_right') {
        // Bottom-right corner logo
        l = 0.65;
        t = 0.88;
        w = 0.35;
        h = 0.12;
      }

      final cleaned = await _watermarkService.eraseRegion(
        _currentBytes,
        normLeft: l,
        normTop: t,
        normWidth: w,
        normHeight: h,
      );

      if (mounted) {
        setState(() {
          _currentBytes = cleaned;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cleaned $preset area successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SGTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SGTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cleaning_services_outlined, color: SGTheme.accent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Document Watermark Remover",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: SGTheme.text),
                      ),
                      Text(
                        "100% Offline AI Inpainting & Color Stripping",
                        style: TextStyle(fontSize: 11, color: SGTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Preview of Cleaned Page
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SGTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _currentBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: SGTheme.accent),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Method 1: Color Watermark Stripper
            const Text(
              "Method 1: Strip Color Watermarks (Diagonal / Background Stamps)",
              style: TextStyle(color: SGTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildColorChip("Faint Gray / Draft", WatermarkColorType.lightGray),
                  const SizedBox(width: 6),
                  _buildColorChip("Red Stamp / Confidential", WatermarkColorType.redStamp),
                  const SizedBox(width: 6),
                  _buildColorChip("Blue Stamp / Banner", WatermarkColorType.blueStamp),
                  const SizedBox(width: 6),
                  _buildColorChip("Yellow Highlight", WatermarkColorType.yellowMarker),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SGTheme.surface,
                  side: BorderSide(color: SGTheme.accent),
                  foregroundColor: SGTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text("Erase Color Watermark"),
                onPressed: _isProcessing ? null : _applyColorStripper,
              ),
            ),
            const SizedBox(height: 14),

            // Method 2: Area / Footer Stamp Eraser
            const Text(
              "Method 2: Erase Unwanted Corner Logos or App Footers",
              style: TextStyle(color: SGTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SGTheme.textSecondary,
                      side: BorderSide(color: SGTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _isProcessing ? null : () => _erasePresetArea('footer'),
                    child: const Text("Clean Footer", style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SGTheme.textSecondary,
                      side: BorderSide(color: SGTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _isProcessing ? null : () => _erasePresetArea('header'),
                    child: const Text("Clean Header", style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SGTheme.textSecondary,
                      side: BorderSide(color: SGTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _isProcessing ? null : () => _erasePresetArea('bottom_right'),
                    child: const Text("Corner Logo", style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Confirm & Cancel
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: SGTheme.textSecondary)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SGTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, _currentBytes),
                  child: const Text("Save Cleaned Document"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChip(String label, WatermarkColorType type) {
    final isSelected = _selectedColorType == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : SGTheme.textSecondary)),
      selected: isSelected,
      selectedColor: SGTheme.accent,
      backgroundColor: SGTheme.bgDark,
      onSelected: (_) => setState(() => _selectedColorType = type),
    );
  }
}
