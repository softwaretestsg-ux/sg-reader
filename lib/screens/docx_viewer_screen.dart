import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _paragraphs
        : _paragraphs.where((p) => p.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search in document...",
                  hintStyle: TextStyle(color: Colors.white54),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final paragraph = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    paragraph,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
