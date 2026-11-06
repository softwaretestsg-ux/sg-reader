import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';

class DocxViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const DocxViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<DocxViewerScreen> createState() => _DocxViewerScreenState();
}

class _DocxViewerScreenState extends State<DocxViewerScreen> {
  final DocumentService _docService = DocumentService();
  List<String> _paragraphs = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _hasUnsavedEdits = false;

  @override
  void initState() {
    super.initState();
    _loadDocx();
  }

  Future<void> _loadDocx() async {
    try {
      final list = await _docService.parseDocxParagraphs(widget.document.path);
      setState(() {
        _paragraphs = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _paragraphs = ["Error reading DOCX file: $e"];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _editParagraph(int index, String currentText) {
    final textController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: Text(
          "Edit Paragraph ${index + 1}",
          style: const TextStyle(color: SGTheme.text, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 5,
          style: const TextStyle(color: SGTheme.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "Paragraph Content",
            labelStyle: const TextStyle(color: SGTheme.textSecondary),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SGTheme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: SGTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SGTheme.accentDeep),
            onPressed: () async {
              final newText = textController.text;
              Navigator.pop(ctx);

              setState(() {
                _paragraphs[index] = newText;
                _hasUnsavedEdits = true;
              });

              await _docService.saveDocxParagraphs(widget.document.path, _paragraphs);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Paragraph updated and saved to Word document."),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addParagraph() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: const Text("Add New Paragraph", style: TextStyle(color: SGTheme.text, fontSize: 16)),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: SGTheme.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "New Paragraph Text",
            labelStyle: const TextStyle(color: SGTheme.textSecondary),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SGTheme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: SGTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SGTheme.accentDeep),
            onPressed: () async {
              final newText = textController.text.trim();
              Navigator.pop(ctx);
              if (newText.isEmpty) return;

              setState(() {
                _paragraphs.add(newText);
                _hasUnsavedEdits = true;
              });

              await _docService.saveDocxParagraphs(widget.document.path, _paragraphs);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("New paragraph added and saved.")),
              );
            },
            child: const Text("Add & Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _paragraphs
        : _paragraphs.where((p) => p.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: SGTheme.text),
                decoration: const InputDecoration(
                  hintText: "Search in document...",
                  hintStyle: TextStyle(color: SGTheme.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                widget.document.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SGTheme.text),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: SGTheme.text),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = "";
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SGTheme.accent),
            tooltip: "Share Word Document",
            onPressed: _shareDocument,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SGTheme.accent))
          : filtered.isEmpty
              ? const Center(
                  child: Text("No text content found in document.", style: TextStyle(color: SGTheme.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final paragraph = filtered[index];
                    final isTable = paragraph.startsWith("[Table Row]");

                    if (isTable) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SGTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SGTheme.border),
                        ),
                        child: Text(
                          paragraph,
                          style: const TextStyle(color: SGTheme.accent, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      );
                    }

                    return InkWell(
                      onTap: () => _editParagraph(index, paragraph),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text(
                          paragraph,
                          style: const TextStyle(
                            color: SGTheme.text,
                            fontSize: 15,
                            height: 1.55,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SGTheme.accentDeep,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Paragraph", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _addParagraph,
      ),
    );
  }
}
