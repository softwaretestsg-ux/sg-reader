import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';
import '../widgets/zoom_controls_dock.dart';

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
  double _currentZoom = 1.0;

  // Multi-touch pinch tracking for real-time finger zoom & pan
  final Map<int, Offset> _pointerPositions = {};
  double _initialPinchDistance = 0.0;
  double _pinchStartZoom = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;

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

  void _updateZoom(double newZoom) {
    final clamped = newZoom.clamp(0.35, 4.0);
    setState(() {
      _currentZoom = clamped;
      if (clamped <= 1.0) {
        _panOffset = Offset.zero;
      }
    });
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
        backgroundColor: Colors.white,
        title: Text(
          "Edit Line ${lineIdx + 1} (Slide ${slideIdx + 1})",
          style: const TextStyle(color: Color(0xFF242424), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Color(0xFF242424)),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "Slide Text",
            labelStyle: const TextStyle(color: Color(0xFF605E5C)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC43E1C), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF605E5C))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC43E1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
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
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        backgroundColor: Colors.white,
        title: Text(
          "Add Line to Slide ${_currentSlideIndex + 1}",
          style: const TextStyle(color: Color(0xFF242424), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF242424)),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "New Line / Bullet",
            labelStyle: const TextStyle(color: Color(0xFF605E5C)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC43E1C), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF605E5C))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC43E1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
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
            child: const Text("Add & Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAE9E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC43E1C),
        foregroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            if (_slides.isNotEmpty)
              Text(
                "Slide ${_currentSlideIndex + 1} of ${_slides.length} • Microsoft PowerPoint",
                style: const TextStyle(fontSize: 11, color: Color(0xFFFFD8CC), fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            tooltip: "Zoom In (+)",
            onPressed: () => _updateZoom(_currentZoom + 0.25),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            tooltip: "Zoom Out (-)",
            onPressed: () => _updateZoom(_currentZoom - 0.25),
          ),
          IconButton(
            icon: Icon(
              _hasUnsavedEdits ? Icons.save : Icons.save_outlined,
              color: Colors.white,
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
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: "Share Presentation",
            onPressed: _sharePresentation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC43E1C)))
          : _slides.isEmpty
              ? const Center(
                  child: Text("No slide content detected in presentation.", style: TextStyle(color: Color(0xFF605E5C))),
                )
              : Stack(
                  children: [
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        _pointerPositions[event.pointer] = event.position;
                        if (_pointerPositions.length == 2) {
                          final keys = _pointerPositions.keys.toList();
                          _initialPinchDistance = (_pointerPositions[keys[0]]! - _pointerPositions[keys[1]]!).distance;
                          _pinchStartZoom = _currentZoom;
                        } else if (_pointerPositions.length == 1 && _currentZoom > 1.05) {
                          _lastFocalPoint = event.position;
                        }
                      },
                      onPointerMove: (event) {
                        if (_pointerPositions.containsKey(event.pointer)) {
                          _pointerPositions[event.pointer] = event.position;
                        }
                        if (_pointerPositions.length == 2 && _initialPinchDistance > 10.0) {
                          final keys = _pointerPositions.keys.toList();
                          final currentDist = (_pointerPositions[keys[0]]! - _pointerPositions[keys[1]]!).distance;
                          final ratio = currentDist / _initialPinchDistance;
                          final targetZoom = (_pinchStartZoom * ratio).clamp(0.35, 4.0);
                          _updateZoom(targetZoom);
                        } else if (_pointerPositions.length == 1 && _currentZoom > 1.05) {
                          final delta = event.position - _lastFocalPoint;
                          _lastFocalPoint = event.position;
                          setState(() {
                            _panOffset += delta;
                          });
                        }
                      },
                      onPointerUp: (event) {
                        _pointerPositions.remove(event.pointer);
                        if (_pointerPositions.length < 2) {
                          _initialPinchDistance = 0.0;
                        }
                      },
                      onPointerCancel: (event) {
                        _pointerPositions.remove(event.pointer);
                        if (_pointerPositions.length < 2) {
                          _initialPinchDistance = 0.0;
                        }
                      },
                      child: PageView.builder(
                        controller: _pageController,
                        physics: _currentZoom > 1.05
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        itemCount: _slides.length,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentSlideIndex = idx;
                            _currentZoom = 1.0;
                            _panOffset = Offset.zero;
                          });
                        },
                        itemBuilder: (ctx, slideIdx) {
                          final slideLines = _slides[slideIdx];
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..translate(_panOffset.dx, _panOffset.dy)
                              ..scale(_currentZoom),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFD1D1D1), width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 18,
                                          offset: const Offset(0, 5),
                                          spreadRadius: 1,
                                        ),
                                      ],
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
                                                  color: const Color(0xFFC43E1C),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "SLIDE ${slideIdx + 1} OF ${_slides.length}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.slideshow_outlined, color: Color(0xFFC43E1C), size: 20),
                                            ],
                                          ),
                                          const Divider(color: Color(0xFFEDEBE9), height: 18, thickness: 1),
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: slideLines.length,
                                              itemBuilder: (ctx, lineIdx) {
                                                final line = slideLines[lineIdx];
                                                final isHeading = lineIdx == 0;
                                                return InkWell(
                                                  onTap: () => _editSlideLine(slideIdx, lineIdx, line),
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (!isHeading)
                                                          const Padding(
                                                            padding: EdgeInsets.only(top: 4, right: 8),
                                                            child: Text(
                                                              "•",
                                                              style: TextStyle(
                                                                color: Color(0xFFC43E1C),
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        Expanded(
                                                          child: Text(
                                                            line,
                                                            style: TextStyle(
                                                              color: isHeading ? const Color(0xFFC43E1C) : const Color(0xFF242424),
                                                              fontSize: isHeading ? 17 : 14,
                                                              fontWeight: isHeading ? FontWeight.bold : FontWeight.w400,
                                                              height: 1.4,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: ZoomControlsDock(
                        currentZoom: _currentZoom,
                        minZoom: 0.35,
                        maxZoom: 4.0,
                        onZoomIn: () => _updateZoom(_currentZoom + 0.25),
                        onZoomOut: () => _updateZoom(_currentZoom - 0.25),
                        onResetZoom: () => _updateZoom(1.0),
                      ),
                    ),
                  ],
                ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC43E1C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Bullet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _addBulletToSlide,
      ),
    );
  }
}
