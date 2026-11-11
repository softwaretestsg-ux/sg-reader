import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/watermark_service.dart';

class DocxViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const DocxViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<DocxViewerScreen> createState() => _DocxViewerScreenState();
}

class _DocxViewerScreenState extends State<DocxViewerScreen> {
  late final WebViewController _controller;
  bool _isDocumentLoaded = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFECE8E1))
      ..addJavaScriptChannel(
        'SGReaderBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleBridgeMessage(msg.message);
        },
      )
      ..loadFlutterAsset('assets/offline_editors/word/word_editor.html');
  }

  Future<void> _sendDocumentToWebView() async {
    try {
      final file = File(widget.document.path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Word document does not exist on disk.")),
        );
        return;
      }
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final filename = widget.document.name;

      await _controller.runJavaScript(
        "window.loadDocument('$base64String', '$filename');",
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error reading Word document: $e")),
      );
    }
  }

  void _handleBridgeMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson);
      final action = data['action'];
      final payload = data['payload'] ?? {};

      if (action == 'ready') {
        _sendDocumentToWebView();
      } else if (action == 'loaded') {
        if (mounted) {
          setState(() {
            _isDocumentLoaded = true;
          });
        }
      } else if (action == 'save') {
        _saveFileFromBase64(payload['base64']);
      } else if (action == 'error') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Word engine notice: ${payload['error']}"),
              backgroundColor: SGTheme.accentDeep,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Bridge parsing error: $e");
    }
  }

  Future<void> _saveFileFromBase64(String base64Data) async {
    try {
      final bytes = base64Decode(base64Data);
      final file = File(widget.document.path);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Word document saved directly to device storage."),
          backgroundColor: Color(0xFF4F7A4A),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save Word document: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _triggerSave() {
    _controller.runJavaScript("window.saveDocument();");
  }

  Future<void> _cleanDocxWatermark() async {
    final watermarkService = WatermarkService();
    final success = await watermarkService.removeDocxWatermark(widget.document.path);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ All watermark shapes removed from Word document! Reloading..."),
          backgroundColor: Color(0xFF4F7A4A),
          duration: Duration(seconds: 3),
        ),
      );
      _sendDocumentToWebView();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No OpenXML watermarks detected or document already clean.")),
      );
    }
  }

  Future<void> _shareDocument() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.document.path)],
        text: "Sharing Word document ${widget.document.name} via Social Googol's SG Reader",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing file: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SGTheme.text),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              "Word Processor (DOCX • Rich Text WYSIWYG)",
              style: TextStyle(fontSize: 11, color: SGTheme.accent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined, color: SGTheme.accent),
            tooltip: "Remove Watermark from Word Document",
            onPressed: _cleanDocxWatermark,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: SGTheme.accent),
            tooltip: "Save Word Document",
            onPressed: _triggerSave,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SGTheme.textSecondary),
            tooltip: "Share Word Document",
            onPressed: _shareDocument,
          ),
        ],
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
