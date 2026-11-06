import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _hasUnsavedEdits = false;
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

  Future<void> _sharePresentation() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.document.path)],
        text: "Sharing PowerPoint presentation ${widget.document.name} via Social Googol's SG Reader",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing presentation: $e")),
      );
    }
  }

  void _editSlideLine(int slideIdx, int lineIdx, String currentText) {
    final textController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: Text(
          "Edit Line ${lineIdx + 1} (Slide ${slideIdx + 1})",
          style: const TextStyle(color: SGTheme.text, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: SGTheme.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "Slide Text",
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
                _slides[slideIdx][lineIdx] = newText;
              });

              await _docService.savePptxSlide(widget.document.path, slideIdx, _slides[slideIdx]);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Slide text updated and saved."),
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

  void _addBulletToSlide() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: Text(
          "Add Line to Slide ${_currentSlideIndex + 1}",
          style: const TextStyle(color: SGTheme.text, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: SGTheme.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "New Line / Bullet",
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
                if (_slides.isEmpty) {
                  _slides.add([newText]);
                } else {
                  _slides[_currentSlideIndex].add(newText);
                }
              });

              await _docService.savePptxSlide(widget.document.path, _currentSlideIndex, _slides[_currentSlideIndex]);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Line added and slide saved.")),
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
                "Slide ${_currentSlideIndex + 1} of ${_slides.length} (Tap text to edit)",
                style: const TextStyle(fontSize: 11, color: SGTheme.accent),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _hasUnsavedEdits ? Icons.save : Icons.save_outlined,
              color: _hasUnsavedEdits ? SGTheme.accent : SGTheme.textSecondary,
            ),
            tooltip: "Save Presentation",
            onPressed: () async {
              if (_slides.isNotEmpty) {
                await _docService.savePptxSlide(widget.document.path, _currentSlideIndex, _slides[_currentSlideIndex]);
              }
              setState(() => _hasUnsavedEdits = false);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Presentation saved to storage."),
                  backgroundColor: Color(0xFF4F7A4A),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SGTheme.accent),
            tooltip: "Share Presentation",
            onPressed: _sharePresentation,
          ),
        ],
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
                                    return InkWell(
                                      onTap: () => _editSlideLine(slideIdx, lineIdx, line),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Text(
                                          line,
                                          style: TextStyle(
                                            color: isHeading ? SGTheme.accent : SGTheme.text,
                                            fontSize: isHeading ? 17 : 14,
                                            fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
                                            height: 1.45,
                                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SGTheme.accentDeep,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Bullet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _addBulletToSlide,
      ),
    );
  }
}
