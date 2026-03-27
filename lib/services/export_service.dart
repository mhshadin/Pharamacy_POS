import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver/file_saver.dart';
import 'package:excel/excel.dart';

import 'package:intl/intl.dart';
import '../models/sale_record.dart';
import '../models/product.dart';
import '../l10n/app_strings.dart';
import '../utils/med_type_units.dart';

class ExportService {
  static Future<String?> exportToCsv(
    List<SaleRecord> sales,
    String title,
  ) async {
    // Offload heavy string building to a background thread
    final bytes = await compute(_generateCsvBytes, sales);

    try {
      final path = await FileSaver.instance.saveFile(
        name: '${title.replaceAll(' ', '_')}_sales_report',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      return path;
    } catch (e) {
      debugPrint('Error during FileSaver CSV export: $e');
      return null;
    }
  }

  static Future<Uint8List> _generateCsvBytes(List<SaleRecord> sales) async {
    List<List<dynamic>> rows = [
      [
        'Invoice Number',
        'Date',
        'Product Name',
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
    return Uint8List.fromList(csvData.codeUnits);
  }

  static Future<String?> exportToPdf({
    required List<SaleRecord> sales,
    required String title,
    String currencySymbol = '৳',
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
      'regularFont': regularFontData.buffer.asUint8List(),
      'boldFont': boldFontData.buffer.asUint8List(),
    };

    // Offload PDF generation to a background thread
    final bytes = await compute(_generatePdfBytes, args);

    try {
      debugPrint('Starting FileSaver for PDF export...');
      final path = await FileSaver.instance.saveFile(
        name: '${title.replaceAll(' ', '_')}_sales_report',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      debugPrint('FileSaver finished! Saved to: $path');
      return path;
    } catch (e) {
      debugPrint('Error during FileSaver PDF export: $e');
      return null;
    }
  }

  static Future<Uint8List> _generatePdfBytes(Map<String, dynamic> args) async {
    final List<SaleRecord> sales = args['sales'];
    final String title = args['title'];
    final String currencySymbol = args['currencySymbol'];
    final Uint8List regularFontBytes = args['regularFont'];
    final Uint8List boldFontBytes = args['boldFont'];

    final pdf = pw.Document();
    final fontRegular = pw.Font.ttf(regularFontBytes.buffer.asByteData());
    final fontBold = pw.Font.ttf(boldFontBytes.buffer.asByteData());
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
              headers: ['Date', 'Invoice', 'Product', 'Qty', 'Amount'],
              data: sales.map((sale) {
                final dateStr = dateFormat.format(sale.date);
                final qtyStr =
                    '${sale.effectiveQuantity}${sale.returnedQuantity > 0 ? '\n(-${sale.returnedQuantity})' : ''}';
                return [
                  dateStr,
                  sale.invoiceNumber ?? 'N/A',
                  sale.productName,
                  qtyStr,
                  '$currencySymbol${sale.effectiveAmount.toStringAsFixed(2)}',
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
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
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
    String title,
  ) async {
    final bytes = await compute(_generateProductCsvBytes, products);
    try {
      final path = await FileSaver.instance.saveFile(
        name: '${title.replaceAll(' ', '_')}_report',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      return path;
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List> _generateProductCsvBytes(
    List<Product> products,
  ) async {
    List<List<dynamic>> rows = [
      ['Name', 'Generic', 'Type', 'Barcode', 'Unit 1 Stock', 'Unit 2 Stock', 'Total Pieces', 'Expiry'],
    ];
    for (var p in products) {
      rows.add([
        p.name,
        p.generic,
        p.medType ?? 'Tablet',
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
    return Uint8List.fromList(csvData.codeUnits);
  }

  static Future<String?> exportProductsToPdf({
    required List<Product> products,
    required String title,
    required AppStrings l10n,
  }) async {
    final regularFontData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final args = {
      'products': products,
      'title': title,
      'l10n': l10n,
      'regularFont': regularFontData.buffer.asUint8List(),
      'boldFont': boldFontData.buffer.asUint8List(),
    };

    final bytes = await compute(_generateProductPdfBytes, args);
    try {
      final path = await FileSaver.instance.saveFile(
        name: '${title.replaceAll(' ', '_')}_report',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      return path;
    } catch (e) {
      return null;
    }
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
    final fontRegular = pw.Font.ttf(regularFontBytes.buffer.asByteData());
    final fontBold = pw.Font.ttf(boldFontBytes.buffer.asByteData());
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
              headers: ['Product Name', 'Generic', 'Type', 'Stock', 'Expiry'],
              data: products.map((p) {
                return [
                  p.name,
                  p.generic,
                  p.medType ?? 'Tablet',
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
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
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
    String title,
  ) async {
    final args = {'products': products, 'orderQtys': orderQtys};
    final bytes = await compute(_generateOrderListCsvBytes, args);
    try {
      final path = await FileSaver.instance.saveFile(
        name: '${title.replaceAll(' ', '_')}_order_list',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      return path;
    } catch (e) {
      debugPrint('Error during order list CSV export: $e');
      return null;
    }
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
        p.stockStrips,
        p.totalPieces,
        orderQtys[p.id] ?? 0,
      ]);
    }
    final csvData = rows.map((row) => row.map((v) => '"$v"').join(',')).join('\n');
    return Uint8List.fromList(csvData.codeUnits);
  }

  static Future<String?> exportOrderListToPdf({
    required List<Product> products,
    required Map<String, int> orderQtys,
    required String title,
    required AppStrings l10n,
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
      'regularFont': regularFontData.buffer.asUint8List(),
      'boldFont': boldFontData.buffer.asUint8List(),
    };

    final bytes = await compute(_generateOrderListPdfBytes, args);
    try {
      final path = await FileSaver.instance.saveFile(
        name: '${title.replaceAll(' ', '_')}_order_list',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      return path;
    } catch (e) {
      debugPrint('Error during order list PDF export: $e');
      return null;
    }
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
    final fontRegular = pw.Font.ttf(regularFontBytes.buffer.asByteData());
    final fontBold = pw.Font.ttf(boldFontBytes.buffer.asByteData());
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
                'Stock (Level 2 / Total Pcs)',
                'Boxes/Units to Order',
              ],
              data: products.map((p) {
                final unitLabels = MedTypeUnits.getLabels(p.medType, l10n);
                return [
                  p.name,
                  p.generic,
                  p.companyName ?? '-',
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
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
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

      final bytes = Uint8List.fromList(csvData.codeUnits);

      final path = await FileSaver.instance.saveFile(
        name: title.replaceAll(' ', '_'),
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      return path;
    } catch (e) {
      debugPrint('Error during bulk import CSV template export: $e');
      return null;
    }
  }

  static Future<String?> exportBulkImportTemplateExcel(
    List<String> headers,
    List<List<dynamic>> rows, {
    String title = 'bulk_import_template',
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

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel template');
      }

      final path = await FileSaver.instance.saveFile(
        name: title.replaceAll(' ', '_'),
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.other,
      );

      return path;
    } catch (e) {
      debugPrint('Error during bulk import Excel template export: $e');
      return null;
    }
  }
}
