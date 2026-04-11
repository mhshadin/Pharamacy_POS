import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

import 'package:intl/intl.dart';
import '../models/sale_record.dart';
import '../models/product.dart';
import '../l10n/app_strings.dart';
import '../utils/med_type_units.dart';
import 'export_save_helper.dart';

class ExportService {
  /// Exact bytes for asset [ByteData] — avoids reading past the file in a pooled buffer.
  static Uint8List _assetBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  static Future<String?> exportToCsv(
    List<SaleRecord> sales,
    String title, {
    String? saveDirectoryPath,
  }) async {
    // Offload heavy string building to a background thread
    final bytes = await compute(_generateCsvBytes, sales);

    final baseName = '${title.replaceAll(' ', '_')}_sales_report';
    return ExportSaveHelper.save(
      bytes: bytes,
      baseName: baseName,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
      saveDirectoryPath: saveDirectoryPath,
    );
  }

  static Future<Uint8List> _generateCsvBytes(List<SaleRecord> sales) async {
    List<List<dynamic>> rows = [
      [
        'Invoice Number',
        'Date',
        'Product Name',
        'Med Type',
        'Power',
        'Batch Number',
        'Cost Price Per Pc',
        'Original Quantity',
        'Quantity Sold',
        'Returned Quantity',
        'Unit Price',
        'Total Amount',
      ],
    ];

    for (var sale in sales) {
      // Guard against division by zero
      final unitPrice = sale.effectiveQuantity == 0
          ? '0.00'
          : (sale.effectiveAmount / sale.effectiveQuantity).toStringAsFixed(2);

      rows.add([
        sale.invoiceNumber ?? 'N/A',
        sale.date.toIso8601String(),
        sale.productName,
        sale.medType ?? '',
        sale.power ?? '',
        sale.batchNumber ?? '',
        sale.costPricePerPc.toStringAsFixed(4),
        sale.quantity,
        sale.effectiveQuantity,
        sale.returnedQuantity,
        unitPrice,
        sale.effectiveAmount,
      ]);
    }

    // Use a simple manual CSV conversion
    String csvData = rows
        .map((row) => row.map((v) => '"$v"').join(','))
        .join('\n');
    return Uint8List.fromList(utf8.encode(csvData));
  }

  static Future<String?> exportToPdf({
    required List<SaleRecord> sales,
    required String title,
    String currencySymbol = '৳',
    String? saveDirectoryPath,
  }) async {
    // Load fonts locally on the main thread to prevent network timeouts
    final regularFontData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final args = {
      'sales': sales,
      'title': title,
      'currencySymbol': currencySymbol,
      'regularFont': _assetBytes(regularFontData),
      'boldFont': _assetBytes(boldFontData),
    };

    // Offload PDF generation to a background thread
    final bytes = await compute(_generatePdfBytes, args);

    debugPrint('Starting PDF export save...');
    final baseName = '${title.replaceAll(' ', '_')}_sales_report';
    final path = await ExportSaveHelper.save(
      bytes: bytes,
      baseName: baseName,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      saveDirectoryPath: saveDirectoryPath,
    );
    if (path != null) debugPrint('PDF export saved to: $path');
    return path;
  }

  static Future<Uint8List> _generatePdfBytes(Map<String, dynamic> args) async {
    final List<SaleRecord> sales = args['sales'];
    final String title = args['title'];
    final String currencySymbol = args['currencySymbol'];
    final Uint8List regularFontBytes = args['regularFont'];
    final Uint8List boldFontBytes = args['boldFont'];

    final pdf = pw.Document();
    final fontRegular = pw.Font.ttf(ByteData.sublistView(regularFontBytes));
    final fontBold = pw.Font.ttf(ByteData.sublistView(boldFontBytes));
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Sales Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Invoice',
                'Product',
                'Type',
                'Power',
                'Batch',
                'Qty',
                'Amount',
                'Cost/Pc',
              ],
              data: sales.map((sale) {
                final dateStr = dateFormat.format(sale.date);
                final qtyStr =
                    '${sale.effectiveQuantity}${sale.returnedQuantity > 0 ? '\n(-${sale.returnedQuantity})' : ''}';
                return [
                  dateStr,
                  sale.invoiceNumber ?? 'N/A',
                  sale.productName,
                  sale.medType ?? '',
                  sale.power ?? '',
                  sale.batchNumber ?? '',
                  qtyStr,
                  '$currencySymbol${sale.effectiveAmount.toStringAsFixed(2)}',
                  sale.costPricePerPc.toStringAsFixed(4),
                ];
              }).toList(),
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Revenue: $currencySymbol${sales.fold(0.0, (sum, s) => sum + s.effectiveAmount).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // --- PRODUCT EXPORTS ---

  static Future<String?> exportProductsToCsv(
    List<Product> products,
    String title, {
    String? saveDirectoryPath,
  }) async {
    final bytes = await compute(_generateProductCsvBytes, products);
    final baseName = '${title.replaceAll(' ', '_')}_report';
    return ExportSaveHelper.save(
      bytes: bytes,
      baseName: baseName,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
      saveDirectoryPath: saveDirectoryPath,
    );
  }

  static Future<Uint8List> _generateProductCsvBytes(
    List<Product> products,
  ) async {
    List<List<dynamic>> rows = [
      [
        'Name',
        'Generic',
        'Company',
        'Type',
        'Power',
        'Barcode',
        'Unit 1 Stock',
        'Unit 2 Stock',
        'Total Pieces',
        'Expiry',
      ],
    ];
    for (var p in products) {
      rows.add([
        p.name,
        p.generic,
        p.companyName ?? '',
        p.medType ?? 'Tablet',
        p.power ?? '',
        p.barcode ?? 'N/A',
        p.stockStrips,
        p.stockPcs,
        p.totalPieces,
        p.expiryDate != null
            ? DateFormat('dd/MM/yyyy').format(p.expiryDate!)
            : 'N/A',
      ]);
    }
    String csvData = rows
        .map((row) => row.map((v) => '"$v"').join(','))
        .join('\n');
    return Uint8List.fromList(utf8.encode(csvData));
  }

  static Future<String?> exportProductsToPdf({
    required List<Product> products,
    required String title,
    required AppStrings l10n,
    String? saveDirectoryPath,
  }) async {
    final regularFontData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final args = {
      'products': products,
      'title': title,
      'l10n': l10n,
      'regularFont': _assetBytes(regularFontData),
      'boldFont': _assetBytes(boldFontData),
    };

    final bytes = await compute(_generateProductPdfBytes, args);
    final baseName = '${title.replaceAll(' ', '_')}_report';
    return ExportSaveHelper.save(
      bytes: bytes,
      baseName: baseName,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      saveDirectoryPath: saveDirectoryPath,
    );
  }

  static Future<Uint8List> _generateProductPdfBytes(
    Map<String, dynamic> args,
  ) async {
    final List<Product> products = args['products'];
    final String title = args['title'];
    final AppStrings l10n = args['l10n'];
    final Uint8List regularFontBytes = args['regularFont'];
    final Uint8List boldFontBytes = args['boldFont'];

    final pdf = pw.Document();
    final fontRegular = pw.Font.ttf(ByteData.sublistView(regularFontBytes));
    final fontBold = pw.Font.ttf(ByteData.sublistView(boldFontBytes));
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Generated on: ${dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Product Name',
                'Generic',
                'Company',
                'Type',
                'Power',
                'Stock',
                'Expiry',
              ],
              data: products.map((p) {
                return [
                  p.name,
                  p.generic,
                  p.companyName ?? '-',
                  p.medType ?? 'Tablet',
                  p.power?.trim().isNotEmpty == true ? p.power!.trim() : '-',
                  '${p.stockStrips} ${MedTypeUnits.getLabels(p.medType, l10n)['unit2']?.toLowerCase() ?? 'str'} / ${p.stockPcs} ${MedTypeUnits.getLabels(p.medType, l10n)['unit3']?.toLowerCase() ?? 'pcs'}',
                  p.expiryDate != null
                      ? dateFormat.format(p.expiryDate!)
                      : 'N/A',
                ];
              }).toList(),
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // --- ORDER LIST EXPORTS (filter-aware, with per-product order qty) ---

  static Future<String?> exportOrderListToCsv(
    List<Product> products,
    Map<String, int> orderQtys,
    String title, {
    String? saveDirectoryPath,
  }) async {
    final args = {'products': products, 'orderQtys': orderQtys};
    final bytes = await compute(_generateOrderListCsvBytes, args);
    final baseName = '${title.replaceAll(' ', '_')}_order_list';
    return ExportSaveHelper.save(
      bytes: bytes,
      baseName: baseName,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
      saveDirectoryPath: saveDirectoryPath,
    );
  }

  static Future<Uint8List> _generateOrderListCsvBytes(
    Map<String, dynamic> args,
  ) async {
    final List<Product> products = args['products'];
    final Map<String, int> orderQtys = args['orderQtys'];

    List<List<dynamic>> rows = [
      [
        'Product Name',
        'Generic',
        'Company',
        'Power',
        'Stock (Level 2)',
        'Stock (Total Pieces)',
        'Boxes to Order',
      ],
    ];
    for (var p in products) {
      rows.add([
        p.name,
        p.generic,
        p.companyName ?? '',
        p.power ?? '',
        p.stockStrips,
        p.totalPieces,
        orderQtys[p.id] ?? 0,
      ]);
    }
    final csvData = rows.map((row) => row.map((v) => '"$v"').join(',')).join('\n');
    return Uint8List.fromList(utf8.encode(csvData));
  }

  static Future<String?> exportOrderListToPdf({
    required List<Product> products,
    required Map<String, int> orderQtys,
    required String title,
    required AppStrings l10n,
    String? saveDirectoryPath,
  }) async {
    final regularFontData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final args = {
      'products': products,
      'orderQtys': orderQtys,
      'title': title,
      'l10n': l10n,
      'regularFont': _assetBytes(regularFontData),
      'boldFont': _assetBytes(boldFontData),
    };

    final bytes = await compute(_generateOrderListPdfBytes, args);
    final baseName = '${title.replaceAll(' ', '_')}_order_list';
    return ExportSaveHelper.save(
      bytes: bytes,
      baseName: baseName,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      saveDirectoryPath: saveDirectoryPath,
    );
  }

  static Future<Uint8List> _generateOrderListPdfBytes(
    Map<String, dynamic> args,
  ) async {
    final List<Product> products = args['products'];
    final Map<String, int> orderQtys = args['orderQtys'];
    final String title = args['title'];
    final AppStrings l10n = args['l10n'];
    final Uint8List regularFontBytes = args['regularFont'];
    final Uint8List boldFontBytes = args['boldFont'];

    final pdf = pw.Document();
    final fontRegular = pw.Font.ttf(ByteData.sublistView(regularFontBytes));
    final fontBold = pw.Font.ttf(ByteData.sublistView(boldFontBytes));
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Generated: ${dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Product Name',
                'Generic',
                'Company',
                'Power',
                'Stock (Level 2 / Total Pcs)',
                'Boxes/Units to Order',
              ],
              data: products.map((p) {
                final unitLabels = MedTypeUnits.getLabels(p.medType, l10n);
                return [
                  p.name,
                  p.generic,
                  p.companyName ?? '-',
                  p.power?.trim().isNotEmpty == true ? p.power!.trim() : '-',
                  '${p.stockStrips} ${unitLabels['unit2']?.toLowerCase() ?? 'str'} / ${p.totalPieces} pcs',
                  '${orderQtys[p.id] ?? 0} ${unitLabels['unit1']?.toLowerCase() ?? 'bx'}',
                ];
              }).toList(),
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 28,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // --- BULK IMPORT TEMPLATE EXPORTS ---

  static Future<String?> exportBulkImportTemplateCsv(
    List<String> headers,
    List<List<dynamic>> rows, {
    String title = 'bulk_import_template',
    String? saveDirectoryPath,
  }) async {
    try {
      final allRows = <List<dynamic>>[
        headers,
        ...rows,
      ];

      final csvData = allRows
          .map(
            (row) => row.map((v) => '"$v"').join(','),
          )
          .join('\n');

      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final baseName = title.replaceAll(' ', '_');
      return ExportSaveHelper.save(
        bytes: bytes,
        baseName: baseName,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
        saveDirectoryPath: saveDirectoryPath,
      );
    } catch (e) {
      debugPrint('Error during bulk import CSV template export: $e');
      return null;
    }
  }

  static Future<String?> exportBulkImportTemplateExcel(
    List<String> headers,
    List<List<dynamic>> rows, {
    String title = 'bulk_import_template',
    String? saveDirectoryPath,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Template'];

      // Write headers
      for (int col = 0; col < headers.length; col++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
            )
            .value = TextCellValue(headers[col]);
      }

      // Write data rows
      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (int c = 0; c < row.length && c < headers.length; c++) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: c,
                  rowIndex: r + 1,
                ),
              )
              .value = TextCellValue(row[c]?.toString() ?? '');
        }
      }

      final encoded = excel.encode();
      if (encoded == null) {
        throw Exception('Failed to encode Excel template');
      }

      final bytes = Uint8List.fromList(encoded);
      final baseName = title.replaceAll(' ', '_');
      return ExportSaveHelper.save(
        bytes: bytes,
        baseName: baseName,
        fileExtension: 'xlsx',
        mimeType: MimeType.other,
        saveDirectoryPath: saveDirectoryPath,
      );
    } catch (e) {
      debugPrint('Error during bulk import Excel template export: $e');
      return null;
    }
  }
}
