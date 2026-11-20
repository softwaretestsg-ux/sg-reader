import 'package:flutter/material.dart';
import '../services/tts_service.dart';

enum LiquidTheme {
  paper,
  sepia,
  night,
}

class LiquidReaderView extends StatefulWidget {
  final List<String> pagesText;
  final String documentTitle;
  final VoidCallback onExitLiquidMode;

  const LiquidReaderView({
    Key? key,
    required this.pagesText,
    required this.documentTitle,
    required this.onExitLiquidMode,
  }) : super(key: key);

  @override
  State<LiquidReaderView> createState() => _LiquidReaderViewState();
}

class _LiquidReaderViewState extends State<LiquidReaderView> {
  final TtsService _ttsService = TtsService();
  double _fontSize = 17.0;
  LiquidTheme _currentTheme = LiquidTheme.paper;
  int _activePage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ttsService.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _ttsService.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (_currentTheme) {
      case LiquidTheme.sepia:
        return const Color(0xFFFBF0D9);
      case LiquidTheme.night:
        return const Color(0xFF141414);
      case LiquidTheme.paper:
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get _textColor {
    switch (_currentTheme) {
      case LiquidTheme.sepia:
        return const Color(0xFF4A3B2C);
      case LiquidTheme.night:
        return const Color(0xFFE4E4E4);
      case LiquidTheme.paper:
      default:
        return const Color(0xFF202020);
    }
  }

  Color get _headerBgColor {
    switch (_currentTheme) {
      case LiquidTheme.sepia:
        return const Color(0xFFEFE2C5);
      case LiquidTheme.night:
        return const Color(0xFF1E1E1E);
      case LiquidTheme.paper:
      default:
        return const Color(0xFFF3F2F1);
    }
  }

  void _readCurrentPageAloud() {
    if (_activePage < widget.pagesText.length) {
      final text = widget.pagesText[_activePage];
      if (_ttsService.playbackState == TtsPlaybackState.playing) {
        _ttsService.pause();
      } else {
        _ttsService.speak(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: Column(
        children: [
          // Liquid Mode Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _headerBgColor,
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB04A24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "LIQUID REFLOW",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),

                // Font Size Scaling: A- / A+
                IconButton(
                  icon: const Icon(Icons.text_decrease, size: 20),
                  color: _textColor,
                  tooltip: "Decrease Font Size",
                  onPressed: () {
                    if (_fontSize > 13) setState(() => _fontSize -= 2);
                  },
                ),
                Text(
                  "${_fontSize.toInt()}pt",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase, size: 20),
                  color: _textColor,
                  tooltip: "Increase Font Size",
                  onPressed: () {
                    if (_fontSize < 30) setState(() => _fontSize += 2);
                  },
                ),
                const Spacer(),

                // Theme Switcher: Paper / Sepia / Night
                PopupMenuButton<LiquidTheme>(
                  icon: Icon(Icons.palette_outlined, color: _textColor, size: 20),
                  tooltip: "Reading Theme",
                  onSelected: (theme) => setState(() => _currentTheme = theme),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: LiquidTheme.paper,
                      child: Text("Paper White (Standard)"),
                    ),
                    const PopupMenuItem(
                      value: LiquidTheme.sepia,
                      child: Text("Sepia Warmth (Book Mode)"),
                    ),
                    const PopupMenuItem(
                      value: LiquidTheme.night,
                      child: Text("AMOLED Night (Eye Saver)"),
                    ),
                  ],
                ),

                // Exit Liquid Reflow Button
                IconButton(
                  icon: Icon(Icons.fullscreen_exit, color: _textColor),
                  tooltip: "Exit Liquid Mode (Original Page Layout)",
                  onPressed: widget.onExitLiquidMode,
                ),
              ],
            ),
          ),

          // Scrollable Reading Canvas
          Expanded(
            child: widget.pagesText.isEmpty
                ? Center(
                    child: Text(
                      "No readable text found in document for Liquid Reflow.",
                      style: TextStyle(color: _textColor.withOpacity(0.6)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: widget.pagesText.length,
                    itemBuilder: (ctx, idx) {
                      final pageContent = widget.pagesText[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "PAGE ${idx + 1} OF ${widget.pagesText.length}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: _textColor.withOpacity(0.45),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up, size: 18),
                                  color: const Color(0xFFB04A24),
                                  tooltip: "Read Page Aloud (TTS)",
                                  onPressed: () {
                                    _activePage = idx;
                                    _readCurrentPageAloud();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              pageContent.isEmpty ? "[Blank Page]" : pageContent,
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.7,
                                color: _textColor,
                                fontFamily: '-apple-system, Roboto, Calibri, sans-serif',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.withOpacity(0.2)),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Floating Natural TTS Audio Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _headerBgColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _ttsService.playbackState == TtsPlaybackState.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: const Color(0xFFB04A24),
                    size: 36,
                  ),
                  tooltip: _ttsService.playbackState == TtsPlaybackState.playing ? "Pause TTS" : "Listen Aloud",
                  onPressed: _readCurrentPageAloud,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _ttsService.playbackState == TtsPlaybackState.playing ? "Reading Aloud (Page ${_activePage + 1})" : "Offline TTS Audio",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                    Text(
                      "Language: ${_ttsService.currentLanguage} • Rate: ${(_ttsService.speechRate * 2).toStringAsFixed(1)}x",
                      style: TextStyle(fontSize: 11, color: _textColor.withOpacity(0.6)),
                    ),
                  ],
                ),
                const Spacer(),

                // Speed Rate Menu
                PopupMenuButton<double>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${(_ttsService.speechRate * 2).toStringAsFixed(1)}x",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                  ),
                  onSelected: (rate) => _ttsService.setSpeechRate(rate / 2),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 0.75, child: Text("0.75x")),
                    const PopupMenuItem(value: 1.0, child: Text("1.0x (Normal)")),
                    const PopupMenuItem(value: 1.25, child: Text("1.25x")),
                    const PopupMenuItem(value: 1.5, child: Text("1.5x (Fast)")),
                    const PopupMenuItem(value: 2.0, child: Text("2.0x (Ultra)")),
                  ],
                ),
                const SizedBox(width: 8),

                // Language Switcher (English / Hindi)
                PopupMenuButton<String>(
                  icon: Icon(Icons.language, size: 20, color: _textColor),
                  tooltip: "Speech Language",
                  onSelected: (lang) => _ttsService.setLanguage(lang),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: "en-US", child: Text("English (US)")),
                    const PopupMenuItem(value: "en-IN", child: Text("English (India)")),
                    const PopupMenuItem(value: "hi-IN", child: Text("हिन्दी (Hindi)")),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
