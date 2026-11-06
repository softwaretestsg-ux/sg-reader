import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_slides.isNotEmpty)
              Text(
                "Slide ${_currentSlideIndex + 1} of ${_slides.length}",
                style: const TextStyle(fontSize: 11, color: Color(0xFF34D399)),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _slides.isEmpty
              ? const Center(
                  child: Text("No slide content detected in presentation.", style: TextStyle(color: Colors.white70)),
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
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "SLIDE ${slideIdx + 1}",
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Icon(Icons.slideshow_outlined, color: Colors.white54),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 24),
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
                                          color: isHeading ? const Color(0xFF34D399) : Colors.white,
                                          fontSize: isHeading ? 18 : 14,
                                          fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
                                          height: 1.4,
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
