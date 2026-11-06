import 'package:flutter/material.dart';
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
  bool _hasUnsavedChanges = false;

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
        title: Text("Edit Cell [R${rowIndex + 1}:C${colIndex + 1}]"),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Cell Value",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final newVal = textController.text;
              Navigator.pop(ctx);

              setState(() {
                _sheetsData[_currentSheet]![rowIndex][colIndex] = newVal;
                _hasUnsavedChanges = true;
              });

              // Persist locally
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
            const Text(
              "Spreadsheet Editor (Tap cell to edit)",
              style: TextStyle(fontSize: 11, color: Color(0xFF34D399)),
            ),
          ],
        ),
        actions: [
          if (_sheetsData.keys.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: "Switch Sheet",
              onSelected: (sheet) {
                setState(() {
                  _currentSheet = sheet;
                });
              },
              itemBuilder: (ctx) => _sheetsData.keys
                  .map(
                    (s) => PopupMenuItem(
                      value: s,
                      child: Text(s, style: TextStyle(fontWeight: s == _currentSheet ? FontWeight.bold : FontWeight.normal)),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : rows.isEmpty
              ? const Center(
                  child: Text("Sheet is empty or has no readable cells.", style: TextStyle(color: Colors.white70)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (states) => Colors.black26,
                      ),
                      columns: List.generate(
                        rows.first.length,
                        (index) => DataColumn(
                          label: Text(
                            String.fromCharCode(65 + (index % 26)),
                            style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold),
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
                                  style: const TextStyle(color: Colors.white),
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
