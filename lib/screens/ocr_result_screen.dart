import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/ocr_service.dart';
import 'docx_viewer_screen.dart';

class OcrResultScreen extends StatefulWidget {
  final OcrResult result;
  final String title;

  const OcrResultScreen({
    Key? key,
    required this.result,
    this.title = "Extracted Text (OCR)",
  }) : super(key: key);

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  late final TextEditingController _textController;
  final OcrService _ocrService = OcrService();
  bool _isCopied = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.result.fullText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();

    setState(() => _isCopied = true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Text copied to clipboard!"),
        backgroundColor: Color(0xFF4F7A4A),
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _shareText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await Share.share(
      text,
      subject: "Extracted Text via Social Googol SG Reader",
    );
  }

  Future<void> _openInWordEditor() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final baseName = "SG_OCR_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      final path = await _ocrService.exportToDocx(text, baseName);

      if (!mounted) return;
      setState(() => _isSaving = false);

      final doc = DocumentFile(
        path: path,
        name: "$baseName.docx",
        sizeInBytes: File(path).lengthSync(),
        type: DocumentType.word,
        lastOpened: DateTime.now(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocxViewerScreen(document: doc),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating Word document: $e")),
      );
    }
  }

  Future<void> _saveAsTxtFile() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final baseName = "SG_OCR_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      final path = await _ocrService.exportToTxt(text, baseName);

      if (!mounted) return;
      setState(() => _isSaving = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SGTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF4F7A4A), size: 24),
              SizedBox(width: 10),
              Text("Saved Successfully", style: TextStyle(color: SGTheme.text, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("OCR text saved to device storage at:", style: TextStyle(color: SGTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SGTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SGTheme.border),
                ),
                child: Text(path, style: const TextStyle(color: SGTheme.accent, fontSize: 12, fontFamily: 'monospace')),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SGTheme.accentDeep),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving text file: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SGTheme.text),
            ),
            const Text(
              "100% Offline • On-Device Neural Recognition",
              style: TextStyle(fontSize: 11, color: SGTheme.accent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isCopied ? Icons.check_circle : Icons.copy_rounded,
              color: _isCopied ? const Color(0xFF4F7A4A) : SGTheme.text,
            ),
            tooltip: "Copy Text",
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SGTheme.text),
            tooltip: "Share Text",
            onPressed: _shareText,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata & Badges Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: SGTheme.surface,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: SGTheme.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SGTheme.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate, size: 14, color: SGTheme.accent),
                        const SizedBox(width: 5),
                        Text(
                          result.isDevanagari ? "Hindi / Devanagari" : "English / Latin",
                          style: const TextStyle(
                            color: SGTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildStatChip(Icons.text_fields_rounded, "${result.wordCount} words"),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.format_line_spacing_rounded, "${result.lines.length} lines"),
                ],
              ),
            ),

            const Divider(color: SGTheme.border, height: 1),

            // Extracted Text View / Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: SGTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SGTheme.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: result.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: SGTheme.textMuted),
                              SizedBox(height: 12),
                              Text(
                                "No text detected in this document or image.",
                                style: TextStyle(color: SGTheme.textSecondary, fontSize: 14),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Try taking a clearer, well-lit photo.",
                                style: TextStyle(color: SGTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            color: SGTheme.text,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Extracted text will appear here...",
                            hintStyle: TextStyle(color: SGTheme.textMuted),
                          ),
                        ),
                ),
              ),
            ),

            // Bottom Action Bar: Open in Word or Save
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: SGTheme.surface,
                border: const Border(top: BorderSide(color: SGTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SGTheme.text,
                        side: const BorderSide(color: SGTheme.accentBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.text_snippet_outlined, size: 18),
                      label: const Text("Save as .txt", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : _saveAsTxtFile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SGTheme.accentDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_document, size: 18),
                      label: const Text("Open in Word", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: _isSaving ? null : _openInWordEditor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SGTheme.bgDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SGTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: SGTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: SGTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
