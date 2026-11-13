import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../widgets/zoom_controls_dock.dart';

class ExcelEditorScreen extends StatefulWidget {
  final DocumentFile document;

  const ExcelEditorScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<ExcelEditorScreen> createState() => _ExcelEditorScreenState();
}

class _ExcelEditorScreenState extends State<ExcelEditorScreen> {
  late final WebViewController _controller;
  bool _isDocumentLoaded = false;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(SGTheme.bgDark)
      ..addJavaScriptChannel(
        'SGReaderBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleBridgeMessage(msg.message);
        },
      )
      ..loadFlutterAsset('assets/offline_editors/excel/excel_editor.html');
  }

  Future<void> _sendDocumentToWebView() async {
    try {
      final file = File(widget.document.path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Spreadsheet file does not exist on disk.")),
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
        SnackBar(content: Text("Error reading spreadsheet: $e")),
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
      } else if (action == 'zoomChanged') {
        if (mounted && payload['zoom'] != null) {
          setState(() {
            _currentZoom = (payload['zoom'] as num).toDouble();
          });
        }
      } else if (action == 'save') {
        _saveFileFromBase64(payload['base64']);
      } else if (action == 'error') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Spreadsheet engine: ${payload['error']}"),
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
          content: Text("✅ Spreadsheet saved directly to device storage."),
          backgroundColor: Color(0xFF4F7A4A),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save spreadsheet: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _triggerSave() {
    _controller.runJavaScript("window.saveDocument();");
  }

  Future<void> _shareSpreadsheet() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.document.path)],
        text: "Sharing spreadsheet ${widget.document.name} via Social Googol's SG Reader",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing file: $e")),
      );
    }
  }

  void _updateZoom(double newZoom) {
    final clamped = newZoom.clamp(0.6, 3.5);
    _controller.runJavaScript("window.setZoomScale($clamped);");
    setState(() {
      _currentZoom = clamped;
    });
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
              "Spreadsheet Suite (XLS, XLSX, CSV • Formula Engine)",
              style: TextStyle(fontSize: 11, color: SGTheme.accent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: SGTheme.accent),
            tooltip: "Save Spreadsheet",
            onPressed: _triggerSave,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SGTheme.textSecondary),
            tooltip: "Share Spreadsheet",
            onPressed: _shareSpreadsheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),

            // Floating On-Screen Zoom Dock (+ / - / Reset %)
            Positioned(
              bottom: 24,
              right: 18,
              child: ZoomControlsDock(
                currentZoom: _currentZoom,
                minZoom: 0.6,
                maxZoom: 3.5,
                onZoomIn: () => _updateZoom(_currentZoom + 0.2),
                onZoomOut: () => _updateZoom(_currentZoom - 0.2),
                onResetZoom: () => _updateZoom(1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
