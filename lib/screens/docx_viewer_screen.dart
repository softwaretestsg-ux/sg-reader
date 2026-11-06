import 'package:flutter/material.dart';
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SGTheme.accent))
          : filtered.isEmpty
              ? const Center(
                  child: Text("No matching text found.", style: TextStyle(color: SGTheme.textSecondary)),
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        paragraph,
                        style: const TextStyle(
                          color: SGTheme.text,
                          fontSize: 15,
                          height: 1.55,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
