import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/pos_provider.dart';
import '../services/database_helper.dart';
import '../services/ocr_service.dart';
import '../services/strip_ai_model_store.dart';
import '../utils/colors.dart';
import '../providers/language_provider.dart';

class OcrScanResultScreen extends StatefulWidget {
  final List<OcrMatchResult> results;
  final File capturedImage;
  final List<Product> allProducts;

  const OcrScanResultScreen({
    super.key,
    required this.results,
    required this.capturedImage,
    required this.allProducts,
  });

  @override
  State<OcrScanResultScreen> createState() => _OcrScanResultScreenState();
}

class _OcrScanResultScreenState extends State<OcrScanResultScreen> {
  // Threshold contract:
  // - exactThreshold (in OcrService) controls auto-accept.
  // - displayThreshold here controls what the user can review manually.
  static const double _displayThreshold = 0.60;
  static const int _ocrMaxImageWidth = 1280;
  static const int _ocrJpegQuality = 75;
  static const String _ocrTempDirName = 'ocr_temp';
  late List<OcrMatchResult> _results;
  late File _image;
  late bool _ownsCurrentImage;
  bool _isRetaking = false;

  List<OcrMatchResult> _keepDisplayCandidates(List<OcrMatchResult> results) {
    return results
        .where((r) => r.matchScore >= _displayThreshold)
        .toList();
  }

  String _productDisplayName(Product p) {
    final type = p.medType?.trim();
    final power = p.power?.trim();
    if (power != null && power.isNotEmpty && type != null && type.isNotEmpty) {
      return '${p.name} ($type • $power)';
    }
    if (type != null && type.isNotEmpty) {
      if (power != null && power.isNotEmpty) return '${p.name} ($type • $power)';
      return '${p.name} ($type)';
    }
    if (power != null && power.isNotEmpty) return '${p.name} ($power)';
    return p.name;
  }

  @override
  void initState() {
    super.initState();
    _results = _keepDisplayCandidates(widget.results);
    _image = widget.capturedImage;
    _ownsCurrentImage = _isInOcrTempFolder(_image);
    // Auto-accept exact matches on load.
    for (final r in _results) {
      if (r.matchType == OcrMatchType.exact) {
        r.status = OcrStatus.accepted;
      }
    }
  }

  int get _acceptedCount =>
      _results.where((r) => r.status == OcrStatus.accepted).length;

  bool get _hasUnresolvedPartials => _results.any(
    (r) =>
        r.status != OcrStatus.rejected &&
        r.matchType == OcrMatchType.partial &&
        r.selectedProduct == null,
  );

  Future<void> _retake() async {
    setState(() => _isRetaking = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        setState(() => _isRetaking = false);
        return;
      }
      final imageFile = await _preprocessImageForOcr(File(file.path));

      if (!mounted) return;
      final useStripAi = await StripAiModelStore.instance.isInstalled();
      final newResults = await OcrService.process(
        imageFile,
        widget.allProducts,
        fetchCandidatesForOcr: (t) => DatabaseHelper().getCandidatesForOcr(t),
        useStripAiModel: useStripAi,
      );
      final highConfidenceResults = _keepDisplayCandidates(newResults);

      if (!mounted) return;
      if (highConfidenceResults.isEmpty) {
        await _deleteIfOwned(imageFile);
        if (!mounted) return;
        setState(() => _isRetaking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context
                  .read<LanguageProvider>()
                  .strings
                  .noMedicineDetectedTryAgain,
            ),
            backgroundColor: AppColors.warningOrange,
          ),
        );
        return;
      }

      final previousImage = _image;
      final hadOwnedImage = _ownsCurrentImage;
      setState(() {
        _image = imageFile;
        _ownsCurrentImage = _isInOcrTempFolder(imageFile);
        _results = highConfidenceResults;
        for (final r in _results) {
          if (r.matchType == OcrMatchType.exact) {
            r.status = OcrStatus.accepted;
          }
        }
        _isRetaking = false;
      });
      if (hadOwnedImage) {
        await _deleteIfOwned(previousImage);
      }
    } catch (e) {
      setState(() => _isRetaking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().strings.voiceError(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_ownsCurrentImage) {
      unawaited(_deleteIfOwned(_image));
    }
    super.dispose();
  }

  bool _isInOcrTempFolder(File file) {
    return p.basename(p.dirname(file.path)) == _ocrTempDirName;
  }

  Future<File> _preprocessImageForOcr(File sourceFile) async {
    try {
      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return sourceFile;

      final resized = decoded.width > _ocrMaxImageWidth
          ? img.copyResize(decoded, width: _ocrMaxImageWidth)
          : decoded;
      final jpgBytes = img.encodeJpg(resized, quality: _ocrJpegQuality);

      final tempDir = await getTemporaryDirectory();
      final ocrTempDir = Directory(p.join(tempDir.path, _ocrTempDirName));
      if (!await ocrTempDir.exists()) {
        await ocrTempDir.create(recursive: true);
      }
      final outputPath = p.join(
        ocrTempDir.path,
        'ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(jpgBytes, flush: true);
      return outputFile;
    } catch (_) {
      return sourceFile;
    }
  }

  Future<void> _deleteIfOwned(File file) async {
    if (!await _isAppManagedOcrFile(file)) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<bool> _isAppManagedOcrFile(File file) async {
    final filePath = p.normalize(file.absolute.path);
    if (p.basename(p.dirname(filePath)) != _ocrTempDirName) return false;

    try {
      final tempDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      final tempOcrRoot = p.normalize(p.join(tempDir.path, _ocrTempDirName));
      final docsOcrRoot = p.normalize(p.join(docsDir.path, _ocrTempDirName));
      return p.isWithin(tempOcrRoot, filePath) || p.isWithin(docsOcrRoot, filePath);
    } catch (_) {
      return false;
    }
  }

  void _commitAccepted() {
    final provider = context.read<POSProvider>();
    int addedCount = 0;

    for (final result in _results) {
      if (result.status != OcrStatus.accepted) continue;
      final product = result.resolvedProduct;
      if (product == null) continue;

      // Add 1 pc to cart (user can adjust in the main POS screen).
      final existing = provider.cart.indexWhere(
        (c) => c.product.id == product.id,
      );
      final currentPcs = existing >= 0 ? provider.cart[existing].pcQuantity : 0;
      final currentStrips = existing >= 0
          ? provider.cart[existing].stripQuantity
          : 0;
      provider.setQuantities(product, currentStrips, currentPcs + 1);
      addedCount++;
    }

    Navigator.pop(context);

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().strings.productsAddedToCart(
              addedCount,
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.reviewScanResults,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildImagePreviewBar(),
          Expanded(
            child: _results.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) => _buildResultCard(_results[i]),
                  ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImagePreviewBar() {
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryDark, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.file(_image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.read<LanguageProvider>().strings.scannedImage,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.read<LanguageProvider>().strings.itemsDetected(
                    _results.length,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _isRetaking
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryDark,
                  ),
                )
              : ElevatedButton(
                  onPressed: _retake,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryAccent,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: Text(
                    context.read<LanguageProvider>().strings.retake,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildResultCard(OcrMatchResult result) {
    final isRejected = result.status == OcrStatus.rejected;
    final isAccepted = result.status == OcrStatus.accepted;
    final needsSelection =
        result.matchType == OcrMatchType.partial &&
        result.selectedProduct == null &&
        !isRejected;

    // Card decoration based on status (mirrors HTML mockup).
    Color borderColor;
    Color cardColor;
    if (isRejected) {
      borderColor = AppColors.divider;
      cardColor = AppColors.surfaceLight;
    } else if (isAccepted) {
      borderColor = AppColors.success;
      cardColor = AppColors.white;
    } else if (needsSelection) {
      borderColor = AppColors.warningOrange;
      cardColor = const Color(0xFFFEF3C7);
    } else {
      borderColor = AppColors.cardBorder;
      cardColor = AppColors.white;
    }

    return AnimatedOpacity(
      opacity: isRejected ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(
            color: borderColor,
            width: isAccepted || needsSelection ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isRejected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(result),
              const SizedBox(height: 12),
              _buildMatchSection(result, isRejected),
              const SizedBox(height: 14),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 12),
              _buildActionButtons(result, isRejected, isAccepted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(OcrMatchResult result) {
    final scorePercent = (result.matchScore * 100).toStringAsFixed(0);
    final isHighConfidence = result.matchScore >= 0.80;
    final confidenceColor = isHighConfidence
        ? AppColors.success
        : AppColors.warningOrange;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cropped image region from the strip.
        _buildCropThumbnail(result.croppedBytes),
        const SizedBox(width: 10),
        // Scanned text + confidence badge.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.read<LanguageProvider>().strings.scannedText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: confidenceColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      context.read<LanguageProvider>().strings.matchPercent(
                        int.parse(scorePercent),
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: confidenceColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '"${result.rawText}"',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'RobotoMono',
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildStatusBadge(result.status),
      ],
    );
  }

  Widget _buildCropThumbnail(Uint8List? croppedBytes) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: croppedBytes != null
          ? Image.memory(
              croppedBytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(
                  LucideIcons.scanLine,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : const Center(
              child: Icon(
                LucideIcons.scanLine,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
    );
  }

  Widget _buildStatusBadge(OcrStatus status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case OcrStatus.accepted:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        icon = LucideIcons.checkCircle;
        label = context.read<LanguageProvider>().strings.statusAccepted;
      case OcrStatus.rejected:
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        icon = LucideIcons.xCircle;
        label = context.read<LanguageProvider>().strings.statusRejected;
      case OcrStatus.pending:
        bg = AppColors.warningOrange.withValues(alpha: 0.12);
        fg = AppColors.warningOrange;
        icon = LucideIcons.clock;
        label = context.read<LanguageProvider>().strings.statusPending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchSection(OcrMatchResult result, bool isRejected) {
    if (result.matchType == OcrMatchType.exact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.checkCircle,
                size: 12,
                color: AppColors.success,
              ),
              const SizedBox(width: 5),
              Text(
                context.read<LanguageProvider>().strings.exactMatchFound,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _productDisplayName(result.exactProduct!),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            result.exactProduct!.generic,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    } else {
      // Partial match — show dropdown.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alertCircle,
                size: 12,
                color: AppColors.warningOrange,
              ),
              const SizedBox(width: 5),
              Text(
                context.read<LanguageProvider>().strings.multipleMatchesSelect,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warningOrange,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<Product>(
            initialValue: result.selectedProduct,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.highlightActive,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isRejected ? AppColors.surfaceLight : AppColors.white,
            ),
            hint: Text(
              context.read<LanguageProvider>().strings.selectCorrectProduct,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            items: result.partialOptions
                .map(
                  (p) => DropdownMenuItem<Product>(
                    value: p,
                    child: Text(
                      _productDisplayName(p),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                )
                .toList(),
            onChanged: isRejected
                ? null
                : (selected) {
                    if (selected == null) return;
                    setState(() {
                      result.selectedProduct = selected;
                      result.status = OcrStatus.accepted;
                    });
                  },
          ),
        ],
      );
    }
  }

  Widget _buildActionButtons(
    OcrMatchResult result,
    bool isRejected,
    bool isAccepted,
  ) {
    if (isRejected) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => result.status = OcrStatus.accepted),
          icon: const Icon(LucideIcons.rotateCcw, size: 14),
          label: Text(context.read<LanguageProvider>().strings.undoReject),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.secondaryAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => result.status = OcrStatus.rejected),
            icon: const Icon(LucideIcons.x, size: 14),
            label: Text(context.read<LanguageProvider>().strings.reject),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (result.matchType == OcrMatchType.partial &&
                  result.selectedProduct == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context
                          .read<LanguageProvider>()
                          .strings
                          .selectProductFirst,
                    ),
                    backgroundColor: AppColors.warningOrange,
                  ),
                );
                return;
              }
              setState(() => result.status = OcrStatus.accepted);
            },
            icon: const Icon(LucideIcons.check, size: 14),
            label: Text(context.read<LanguageProvider>().strings.accept),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccepted
                  ? AppColors.success
                  : AppColors.surfaceLight,
              foregroundColor: isAccepted
                  ? AppColors.white
                  : AppColors.primaryDark,
              elevation: isAccepted ? 1 : 0,
              side: isAccepted
                  ? null
                  : const BorderSide(color: AppColors.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.scanLine,
            size: 56,
            color: AppColors.secondaryAccent,
          ),
          const SizedBox(height: 16),
          Text(
            context.read<LanguageProvider>().strings.noMatchesFound,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.read<LanguageProvider>().strings.tryRetakingPhoto,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canCommit = !_hasUnresolvedPartials;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.read<LanguageProvider>().strings.selectedForImport,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontSize: 14,
                ),
              ),
              Text(
                '$_acceptedCount',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canCommit && _acceptedCount > 0
                  ? _commitAccepted
                  : null,
              icon: Icon(
                canCommit ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                size: 20,
              ),
              label: Text(
                canCommit
                    ? context.read<LanguageProvider>().strings.commitValidItems
                    : context
                          .read<LanguageProvider>()
                          .strings
                          .resolveSelectionsFirst,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canCommit && _acceptedCount > 0
                    ? AppColors.primaryDark
                    : AppColors.divider,
                foregroundColor: canCommit && _acceptedCount > 0
                    ? AppColors.white
                    : AppColors.textSecondary,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: canCommit && _acceptedCount > 0 ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
