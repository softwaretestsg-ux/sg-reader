import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';

class ExcelEditorScreen extends StatefulWidget {
  final DocumentFile document;

  const ExcelEditorScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<ExcelEditorScreen> createState() => _ExcelEditorScreenState();
}

class _ExcelEditorScreenState extends State<ExcelEditorScreen> {
  final DocumentService _docService = DocumentService();
  bool _isLoading = true;
  Map<String, List<List<dynamic>>> _sheetsData = {};
  String _currentSheet = '';

  @override
  void initState() {
    super.initState();
    _loadExcel();
  }

  Future<void> _loadExcel() async {
    try {
      final data = await _docService.readExcel(widget.document.path);
      setState(() {
        _sheetsData = data;
        if (data.isNotEmpty) {
          _currentSheet = data.keys.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editCell(int rowIndex, int colIndex, String currentValue) {
    final textController = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: Text(
          "Edit Cell [R${rowIndex + 1}:C${colIndex + 1}]",
          style: const TextStyle(color: SGTheme.text, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: SGTheme.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            labelText: "Cell Value",
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
              final newVal = textController.text;
              Navigator.pop(ctx);

              setState(() {
                _sheetsData[_currentSheet]![rowIndex][colIndex] = newVal;
              });

              await _docService.saveExcelCell(
                widget.document.path,
                _currentSheet,
                rowIndex,
                colIndex,
                newVal,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Cell saved locally."),
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

  @override
  Widget build(BuildContext context) {
    final rows = _sheetsData[_currentSheet] ?? [];

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
              "Spreadsheet Editor (Tap any cell to edit)",
              style: TextStyle(fontSize: 11, color: SGTheme.accent),
            ),
          ],
        ),
        actions: [
          if (_sheetsData.keys.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.table_chart_outlined, color: SGTheme.text),
              tooltip: "Switch Sheet",
              color: SGTheme.surface,
              onSelected: (sheet) {
                setState(() {
                  _currentSheet = sheet;
                });
              },
              itemBuilder: (ctx) => _sheetsData.keys
                  .map(
                    (s) => PopupMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: TextStyle(
                          color: SGTheme.text,
                          fontWeight: s == _currentSheet ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SGTheme.accent))
          : rows.isEmpty
              ? const Center(
                  child: Text("Sheet has no readable data.", style: TextStyle(color: SGTheme.textSecondary)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(SGTheme.surfaceHover),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (states) => SGTheme.surface.withOpacity(0.6),
                      ),
                      columns: List.generate(
                        rows.first.length,
                        (index) => DataColumn(
                          label: Text(
                            String.fromCharCode(65 + (index % 26)),
                            style: const TextStyle(color: SGTheme.accent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      rows: List.generate(
                        rows.length,
                        (rIndex) => DataRow(
                          cells: List.generate(
                            rows[rIndex].length,
                            (cIndex) {
                              final cellVal = rows[rIndex][cIndex]?.toString() ?? "";
                              return DataCell(
                                Text(
                                  cellVal,
                                  style: const TextStyle(color: SGTheme.text),
                                ),
                                onTap: () => _editCell(rIndex, cIndex, cellVal),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
