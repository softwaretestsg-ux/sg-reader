import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';

class PptxViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const PptxViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<PptxViewerScreen> createState() => _PptxViewerScreenState();
}

class _PptxViewerScreenState extends State<PptxViewerScreen> {
  final DocumentService _docService = DocumentService();
  List<List<String>> _slides = [];
  bool _isLoading = true;
  int _currentSlideIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadPptx();
  }

  Future<void> _loadPptx() async {
    try {
      final list = await _docService.parsePptxSlides(widget.document.path);
      setState(() {
        _slides = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _slides = [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            if (_slides.isNotEmpty)
              Text(
                "Slide ${_currentSlideIndex + 1} of ${_slides.length}",
                style: const TextStyle(fontSize: 11, color: SGTheme.accent),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SGTheme.accent))
          : _slides.isEmpty
              ? const Center(
                  child: Text("No slide content detected in presentation.", style: TextStyle(color: SGTheme.textSecondary)),
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentSlideIndex = idx;
                    });
                  },
                  itemBuilder: (ctx, slideIdx) {
                    final slideLines = _slides[slideIdx];
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        color: SGTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: SGTheme.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: SGTheme.accentDeep,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "SLIDE ${slideIdx + 1}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.slideshow_outlined, color: SGTheme.textMuted),
                                ],
                              ),
                              const Divider(color: SGTheme.border, height: 24),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: slideLines.length,
                                  itemBuilder: (ctx, lineIdx) {
                                    final line = slideLines[lineIdx];
                                    final isHeading = lineIdx == 0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        line,
                                        style: TextStyle(
                                          color: isHeading ? SGTheme.accent : SGTheme.text,
                                          fontSize: isHeading ? 17 : 14,
                                          fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
                                          height: 1.45,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
