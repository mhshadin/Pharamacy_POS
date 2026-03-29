import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart' as csv;
import 'package:excel/excel.dart' hide Border;
import 'package:provider/provider.dart';
import 'package:pharmacy_pos/providers/pos_provider.dart';
import 'package:pharmacy_pos/utils/colors.dart';
import 'package:pharmacy_pos/models/product.dart';
import 'package:pharmacy_pos/providers/admin_provider.dart';
import 'package:pharmacy_pos/providers/language_provider.dart';
import 'package:pharmacy_pos/screens/admin/bulk_import_edit_form.dart';
import 'package:pharmacy_pos/services/export_service.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  static const List<String> _expectedHeaders = [
    'Name',
    'Generic',
    'Barcode',
    'PriceBox',
    'StripsPerBox',
    'PcsPerStrip',
    'StockBoxes',
    'MinStock',
    'BatchNo',
    'ExpiryDate',
    'SupplierName',
    'SupplierPhone',
    'MedType',
  ];

  static const List<String> _sampleRow = [
    'Paracetamol 500mg',
    'Paracetamol',
    '1234567890123',
    '20',
    '10',
    '10',
    '5',
    '2',
    'BATCH001',
    '2026-12-31',
    'Best Pharma Supplier',
    '+1234567890',
    'Tablet',
  ];

  bool _isProcessing = false;
  List<BulkImportRecord> _parsedRecords = [];
  List<String> _errors = [];
  String? _fileName;

  // Toggle state to switch between viewing valid items and errors
  bool _showErrorsList = false;
  bool _showTemplatePanel = true;

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _pickAndParseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final extension = path.split('.').last.toLowerCase();

      setState(() {
        _isProcessing = true;
        _fileName = result.files.single.name;
        _parsedRecords = [];
        _errors = [];
        _showErrorsList = false;
      });

      List<List<dynamic>> fields = [];

      if (extension == 'csv') {
        final input = File(path).openRead();
        fields = await input
            .transform(utf8.decoder)
            .transform(csv.CsvToListConverter(shouldParseNumbers: false))
            .toList();
      } else if (extension == 'xlsx') {
        final bytes = File(path).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        if (excel.tables.isNotEmpty) {
          final firstTable = excel.tables.values.first;
          fields = firstTable.rows
              .map(
                (row) => row
                    .map(
                      (cell) =>
                          cell == null ? '' : (cell.value ?? '').toString(),
                    )
                    .toList(),
              )
              .toList();
        }
      } else {
        final l10n = context.read<LanguageProvider>().strings;
        String errorMsg = extension == 'xls'
            ? l10n.xlsLegacyNotSupported
            : l10n.unsupportedFileType(extension);

        setState(() {
          _errors.add(errorMsg);
          _isProcessing = false;
        });
        _showErrorSnack(errorMsg);
        return;
      }

      _processFields(fields);
    } catch (e) {
      final l10n = context.read<LanguageProvider>().strings;
      setState(() {
        _errors.add("${l10n.error}: $e");
        _isProcessing = false;
      });
      _showErrorSnack(l10n.failedToReadFile);
    }
  }

  /// Parse ExpiryDate string: YYYY-MM-DD or DD/MM/YYYY. Returns null if invalid.
  static DateTime? _parseExpiryDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final parts = trimmed.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (c > 999) return DateTime(c, b.clamp(1, 12), a.clamp(1, 31));
        return DateTime(a.clamp(1, 31), b.clamp(1, 12), c);
      }
    }
    return null;
  }

  void _processFields(List<List<dynamic>> fields) {
    final l10n = context.read<LanguageProvider>().strings;
    if (fields.isEmpty) {
      setState(() {
        _errors.add(l10n.fileIsEmpty);
        _isProcessing = false;
      });
      _showErrorSnack(l10n.fileIsEmpty);
      return;
    }

    final headers = fields.first.map((e) => e.toString().trim()).toList();

    for (var expected in _expectedHeaders) {
      if (!headers.contains(expected)) {
        setState(() {
          _errors.add(l10n.missingRequiredColumn(expected));
          _isProcessing = false;
        });
        _showErrorSnack(l10n.missingRequiredColumn(expected));
        return;
      }
    }

    List<BulkImportRecord> tempRecords = [];
    const defaultExpiry = Duration(days: 365);

    for (int i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty || row.length < _expectedHeaders.length) continue;

      try {
        String getString(String colName) =>
            row[headers.indexOf(colName)].toString().trim();
        double getDouble(String colName) =>
            double.tryParse(getString(colName)) ?? 0.0;
        int getInt(String colName) => int.tryParse(getString(colName)) ?? 0;

        final name = getString('Name');
        if (name.isEmpty) {
          _errors.add(l10n.rowSkippedNameEmpty(i + 1));
          continue;
        }

        final spb = getInt('StripsPerBox') > 0 ? getInt('StripsPerBox') : 1;
        final pps = getInt('PcsPerStrip') > 0 ? getInt('PcsPerStrip') : 10;
        final stockBoxes = getInt('StockBoxes');
        final totalPcs = stockBoxes * spb * pps;

        final priceBox = getDouble('PriceBox');
        final priceStrip = spb > 0 ? priceBox / spb : 0.0;
        final pricePc = pps > 0 ? priceStrip / pps : 0.0;

        final minStockBoxes = getInt('MinStock');
        final minStockLevel = minStockBoxes * spb;

        final expiryStr = getString('ExpiryDate');
        DateTime expiry = DateTime.now().add(defaultExpiry);
        final parsed = _parseExpiryDate(expiryStr);
        if (parsed != null) {
          expiry = parsed;
        } else if (expiryStr.isNotEmpty) {
          _errors.add(l10n.invalidExpiryUsingDefault(i + 1, expiryStr));
        }

        final batchNo = getString('BatchNo');
        final batchNumber =
            batchNo.isEmpty ? null : batchNo;

        final product = Product(
          id: "${DateTime.now().millisecondsSinceEpoch}_$i",
          name: name,
          generic: getString('Generic'),
          barcode:
              getString('Barcode').isEmpty ? null : getString('Barcode'),
          priceBox: priceBox,
          priceStrip: priceStrip,
          pricePc: pricePc,
          stripsPerBox: spb,
          pcsPerStrip: pps,
          stockStrips: totalPcs ~/ pps,
          stockPcs: totalPcs % pps,
          minStockLevel: minStockLevel,
          supplierName: getString('SupplierName').isEmpty
              ? null
              : getString('SupplierName'),
          supplierPhone: getString('SupplierPhone').isEmpty
              ? null
              : getString('SupplierPhone'),
          medType: getString('MedType').isEmpty ? 'Tablet' : getString('MedType'),
          expiryDate: expiry,
        );

        tempRecords.add(BulkImportRecord(
          product: product,
          batchNumber: batchNumber,
          expiryDate: expiry,
        ));
      } catch (e) {
        _errors.add(l10n.rowSkippedDataError(i + 1, e.toString()));
      }
    }

    setState(() {
      _parsedRecords = tempRecords;
      _isProcessing = false;
      if (_parsedRecords.isEmpty && _errors.isNotEmpty) {
        _showErrorsList = true;
        _showErrorSnack(l10n.noValidRowsFound);
      }
    });
  }

  void _removeStagedItem(int index) {
    setState(() {
      _parsedRecords.removeAt(index);
    });
  }

  void _clearSession() {
    setState(() {
      _parsedRecords = [];
      _errors = [];
      _fileName = null;
      _showErrorsList = false;
    });
  }

  Future<void> _commitToDatabase() async {
    if (_parsedRecords.isEmpty) return;

    final l10n = context.read<LanguageProvider>().strings;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            l10n.confirmImport,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.confirmImportMsg(_parsedRecords.length),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                l10n.cancelBtn,
                style: const TextStyle(color: AppColors.secondaryAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.yesImport,
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      if (!mounted) return;
      final admin = context.read<AdminProvider>();
      await admin.insertProductsBulk(_parsedRecords);

      if (mounted) {
        await context.read<POSProvider>().loadProducts();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              l10n.bulkImportSuccess(_parsedRecords.length),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final l10nError = context.read<LanguageProvider>().strings;
        setState(() {
          _errors.add(l10nError.databaseInsertFailed(e.toString()));
          _showErrorsList = true;
          _isProcessing = false;
        });
        _showErrorSnack(l10nError.failedToImportReviewErrors);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.bulkImportPreview,
          style: const TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: _isProcessing
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // File Picker Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fileName == null
                                ? l10n.noFileSelected
                                : l10n.selectedFile(_fileName!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickAndParseFile,
                          icon: const Icon(
                            LucideIcons.fileSpreadsheet,
                            size: 18,
                            color: AppColors.white,
                          ),
                          label: Text(
                            _fileName == null ? l10n.selectCsvExcel : l10n.changeBtn,
                            style: const TextStyle(color: AppColors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_showTemplatePanel)
                      _buildTemplateInfoPanel()
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _showTemplatePanel = true);
                          },
                          icon: const Icon(
                            LucideIcons.info,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          label: Text(
                            l10n.showFileStructure,
                            style: const TextStyle(color: AppColors.primaryDark),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    if (_fileName == null) ...[
                      // Empty State Instructions
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
                        child: Center(
                          child: Text(
                            l10n.uploadCsvHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.secondaryAccent,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // --- VIEW TOGGLES ---
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showErrorsList = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_showErrorsList
                                        ? AppColors.primaryDark
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    l10n.readyToImport(_parsedRecords.length),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_showErrorsList
                                          ? AppColors.white
                                          : AppColors.secondaryAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showErrorsList = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _showErrorsList
                                        ? AppColors.error
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    l10n.errorsCount(_errors.length),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _showErrorsList
                                          ? AppColors.white
                                          : AppColors.secondaryAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- LIST VIEWS ---
                      _showErrorsList
                          ? _buildErrorsList()
                          : _buildPreviewList(),

                      const SizedBox(height: 16),

                      // --- ACTIONS (DISCARD & COMMIT) ---
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              onPressed: _clearSession,
                              icon: const Icon(
                                LucideIcons.xCircle,
                                color: AppColors.error,
                              ),
                              label: Text(
                                l10n.cancelBtn,
                                style: const TextStyle(color: AppColors.error),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _parsedRecords.isEmpty
                                  ? null
                                  : _commitToDatabase,
                              icon: const Icon(
                                LucideIcons.database,
                                color: AppColors.white,
                              ),
                              label: Text(
                                l10n.importNItems(_parsedRecords.length),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                disabledBackgroundColor: AppColors.divider,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // Visual list of products sitting in the staging area
  Widget _buildPreviewList() {
    final l10n = context.read<LanguageProvider>().strings;
    if (_parsedRecords.isEmpty) {
      return Center(
        child: Text(
          l10n.noValidProducts,
          style: const TextStyle(color: AppColors.secondaryAccent),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _parsedRecords.length,
      itemBuilder: (context, index) {
        final product = _parsedRecords[index].product;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.generic,
                        style: const TextStyle(
                          color: AppColors.secondaryAccent,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMiniStat(
                            context.read<LanguageProvider>().strings.boxPrice,
                            '\$${product.priceBox.toStringAsFixed(2)}',
                          ),
                          _buildMiniStat(context.read<LanguageProvider>().strings.stockPcsLabel, '${product.totalPieces}'),
                          if (product.barcode != null)
                            _buildMiniStat(context.read<LanguageProvider>().strings.barcodeLabel, product.barcode!),
                          if (product.medType != null)
                            _buildMiniStat(context.read<LanguageProvider>().strings.category, product.medType!),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _openEditFormForRow(index),
                      icon: const Icon(
                        LucideIcons.pencil,
                        color: AppColors.primaryDark,
                      ),
                      tooltip: context.read<LanguageProvider>().strings.editThisRow,
                    ),
                    IconButton(
                      onPressed: () => _removeStagedItem(index),
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: AppColors.error,
                      ),
                      tooltip: context.read<LanguageProvider>().strings.deleteThisRow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditFormForRow(int index) async {
    final record = _parsedRecords[index];
    final admin = context.read<AdminProvider>();

    final updated = await Navigator.of(context).push<BulkImportRecord>(
      MaterialPageRoute(
        builder: (ctx) => BulkImportEditForm(
          record: record,
          admin: admin,
        ),
      ),
    );

    if (!mounted || updated == null) return;

    setState(() {
      _parsedRecords[index] = updated;
    });
  }

  Widget _buildErrorsList() {
    final l10n = context.read<LanguageProvider>().strings;
    if (_errors.isEmpty) {
      return Center(
        child: Text(
          l10n.noErrorsFound,
          style: const TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _errors.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.alertCircle,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errors[index],
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.secondaryAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateInfoPanel() {
    final l10n = context.read<LanguageProvider>().strings;
    final headerLine = _expectedHeaders.join(',');
    final sampleLine = _sampleRow.join(',');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: 18,
                color: AppColors.primaryDark,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.fileStructureExample,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.expiryFormatHint,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryAccent,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final path =
                        await ExportService.exportBulkImportTemplateCsv(
                      _expectedHeaders,
                      [_sampleRow],
                      title: 'bulk_import_template',
                    );
                    if (!mounted) return;
                    if (path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.csvTemplateSuccess,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.csvTemplateFail,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    LucideIcons.download,
                    size: 16,
                    color: AppColors.white,
                  ),
                  label: Text(
                    l10n.downloadCsvTemplate,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final path =
                        await ExportService.exportBulkImportTemplateExcel(
                      _expectedHeaders,
                      [_sampleRow],
                      title: 'bulk_import_template',
                    );
                    if (!mounted) return;
                    if (path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.excelTemplateSuccess,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.excelTemplateFail,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    LucideIcons.download,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  label: Text(
                    l10n.downloadExcel,
                    style: const TextStyle(color: AppColors.primaryDark),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primaryDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 32,
              columns: _expectedHeaders
                  .map(
                    (h) => DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryAccent,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: [
                DataRow(
                  cells: _sampleRow
                      .map(
                        (v) => DataCell(
                          Text(
                            v,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rawCsvExample,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryAccent,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                '$headerLine\n$sampleLine',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
