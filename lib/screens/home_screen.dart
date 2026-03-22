import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/colors.dart';
import '../providers/pos_provider.dart';
import '../providers/admin_provider.dart';
import '../models/cart_item.dart';
import '../services/ocr_service.dart';
import '../widgets/home/out_of_stock_dialog.dart';
import '../widgets/home/pos_scanner_section.dart';
import '../widgets/home/pos_cart_list.dart';
import '../widgets/home/pos_checkout_footer.dart';
import 'admin/expiring_soon_screen.dart';
import 'admin/low_stock_screen.dart';
import 'admin/sales_report_screen.dart';
import 'manual_add_screen.dart';
import 'ocr_scan_result_screen.dart';
import '../widgets/drawer/pos_drawer.dart';
import '../services/speech_service.dart';
import '../utils/product_matcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scanScrollController = ScrollController();
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  // Scanner variables
  late MobileScannerController _cameraController;
  bool _isProcessingScan = false;
  late bool _isCameraActive;

  // Voice search state
  bool _isVoiceSearchActive = false;
  bool _isListeningVoice = false;
  final TextEditingController _voiceSearchController = TextEditingController();
  final FocusNode _voiceSearchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _isCameraActive = !Platform.isWindows;

    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isWindows || !_isCameraActive) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimationController.dispose();
    _scanScrollController.dispose();
    _cameraController.dispose();
    _voiceSearchController.dispose();
    _voiceSearchFocus.dispose();
    super.dispose();
  }

  Future<void> _startHomeVoiceSearch(POSProvider posProvider) async {
    setState(() {
      _isVoiceSearchActive = true;
      _isListeningVoice = true;
      _voiceSearchController.clear();
    });

    await SpeechService.instance.startListening(
      preferredLocaleId: 'en_US',
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _voiceSearchController.text = text;
          _voiceSearchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _voiceSearchController.text.length),
          );
        });

        if (isFinal) {
          setState(() => _isListeningVoice = false);
          _handleHomeFinalSpeech(posProvider, text);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListeningVoice = false);
        if (error.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Voice error: $error',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );
  }

  Future<void> _stopHomeVoiceSearch() async {
    await SpeechService.instance.stopListening();
    if (!mounted) return;
    setState(() {
      _isListeningVoice = false;
      _isVoiceSearchActive = false;
      _voiceSearchController.clear();
    });
  }

  void _handleHomeFinalSpeech(POSProvider posProvider, String text) {
    final best = ProductMatcher.findBestMatch(text, posProvider.products);

    if (best != null) {
      posProvider.updatePcQuantity(best.product, 1);
      setState(() {
        _isVoiceSearchActive = false;
        _voiceSearchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${best.product.name} (1 pc) to cart',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No match – edit the name and tap the search icon.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showModal({required String type, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isSuccess = type == 'success';
        final theme = Theme.of(ctx);
        final screenWidth = MediaQuery.of(ctx).size.width;
        final isNarrow = screenWidth < 380;
        final iconSize = isNarrow ? 60.0 : 72.0;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          icon: Icon(
            isSuccess ? LucideIcons.checkCircle2 : LucideIcons.trash2,
            size: iconSize,
            color: isSuccess ? AppColors.success : AppColors.error,
          ),
          title: Text(
            isSuccess ? 'Sale Complete' : 'Clear Cart?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            if (type == 'clear') ...[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  context.read<POSProvider>().clearCart();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Yes, Clear'),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final pos = context.read<POSProvider>();
                    final admin = context.read<AdminProvider>();
                    final invoiceNumber = await pos.completeSale();
                    await admin.refreshSales();
                    await admin.loadData();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sale Complete! Invoice: $invoiceNumber'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('New Sale'),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isAnyItemOutOfStock(List<CartItem> cart) {
    for (final item in cart) {
      if (item.totalPieces > item.product.totalPieces) {
        return true;
      }
    }
    return false;
  }

  void _showStockWarning(BuildContext context, VoidCallback onProceed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return OutOfStockDialog(onProceed: onProceed);
      },
    );
  }

  Future<void> _handleBarcodeScan(
    String code,
    POSProvider posProvider,
  ) async {
    if (!_isCameraActive || _isProcessingScan) return;

    setState(() => _isProcessingScan = true);

    bool success = false;
    if (mounted) {
      success = await posProvider.handleBarcodeScan(code);
    }
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product not found for barcode: $code'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 0),
        ),
      );
    }

    if (mounted) {
      setState(() => _isProcessingScan = false);
    }
  }

  Future<void> _navigateFromDrawer(Future<void> Function() navigate) async {
    if (!context.mounted) return;
    Navigator.pop(context); // close drawer
    final bool wasOn = _isCameraActive;
    if (wasOn && !Platform.isWindows) _cameraController.stop();
    await navigate();
    if (wasOn && mounted && !Platform.isWindows) _cameraController.start();
  }

  Future<void> _handleOcrScan() async {
    final bool wasOn = _isCameraActive;
    if (wasOn) _cameraController.stop();

    bool loadingDialogOpen = false;

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (file == null) {
        if (wasOn && mounted) _cameraController.start();
        return;
      }

      if (!mounted) return;

      // Show loading dialog while OCR processes.
      loadingDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            color: AppColors.white,
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryDark),
                  SizedBox(height: 16),
                  Text(
                    'Reading strip...',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final imageFile = File(file.path);
      final products = context.read<POSProvider>().products;
      final results = await OcrService.process(imageFile, products);

      if (!mounted) return;
      loadingDialogOpen = false;
      Navigator.pop(context); // dismiss loading dialog

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No medicine names detected. Try again.'),
            backgroundColor: AppColors.warningOrange,
          ),
        );
        if (wasOn && mounted) _cameraController.start();
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrScanResultScreen(
            results: results,
            capturedImage: imageFile,
            allProducts: products,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        if (loadingDialogOpen) {
          loadingDialogOpen = false;
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (wasOn && mounted && !Platform.isWindows) _cameraController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<POSProvider>();
    final cart = posProvider.cart;
    final filteredCart = posProvider.filteredCart;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      drawer: PosDrawer(onNavigate: _navigateFromDrawer),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('PHARMA POS'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isCameraActive ? LucideIcons.camera : LucideIcons.cameraOff,
              color: AppColors.white,
            ),
            onPressed: () {
              if (Platform.isWindows) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camera scanner is restricted on Windows desktop.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setState(() {
                _isCameraActive = !_isCameraActive;
                if (_isCameraActive) {
                  _cameraController.start();
                } else {
                  _cameraController.stop();
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth > 900;

          Widget scannerSection = PosScannerSection(
            cameraController: _cameraController,
            scanAnimation: _scanAnimation,
            isTablet: isLarge,
            isCameraActive: _isCameraActive,
            isProcessingScan: _isProcessingScan,
            onBarcodeScanned: (code) => _handleBarcodeScan(code, posProvider),
            onToggleCamera: () {
              if (Platform.isWindows) return;
              setState(() {
                _isCameraActive = !_isCameraActive;
                if (_isCameraActive) {
                  _cameraController.start();
                } else {
                  _cameraController.stop();
                }
              });
            },
            onManualAdd: () async {
              final bool wasOn = _isCameraActive;
              if (wasOn && !Platform.isWindows) _cameraController.stop();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManualAddScreen()),
              );
              if (wasOn && mounted && !Platform.isWindows) _cameraController.start();
            },
            onOcrScan: _handleOcrScan,
            isVoiceActive: _isVoiceSearchActive,
            onVoiceSearch: () {
              if (_isVoiceSearchActive) {
                _stopHomeVoiceSearch();
              } else {
                _startHomeVoiceSearch(posProvider);
              }
            },
          );

          Widget voiceSearchBar = _VoiceSearchBar(
            isVisible: _isVoiceSearchActive,
            isListening: _isListeningVoice,
            controller: _voiceSearchController,
            focusNode: _voiceSearchFocus,
            onDiscard: _stopHomeVoiceSearch,
            onConfirm: () => _handleHomeFinalSpeech(posProvider, _voiceSearchController.text),
          );

          Widget cartList = PosCartList(
            cart: cart,
            filteredCart: filteredCart,
            provider: posProvider,
          );

          Widget checkoutFooter = PosCheckoutFooter(
            cart: cart,
            total: posProvider.calculateTotal,
            onClear: () => _showModal(
              type: 'clear',
              message: 'Are you sure you want to clear the cart?',
            ),
            onCheckout: () {
              if (_isAnyItemOutOfStock(cart)) {
                _showStockWarning(
                  context,
                  () {
                    _showModal(
                      type: 'success',
                      message: 'Successfully charged ${posProvider.calculateTotal.toStringAsFixed(2)} Taka',
                    );
                  },
                );
              } else {
                _showModal(
                  type: 'success',
                  message: 'Successfully charged ${posProvider.calculateTotal.toStringAsFixed(2)} Taka',
                );
              }
            },
          );

          if (isLarge) {
            return Column(
              children: [
                voiceSearchBar,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed width scanner for tablet/desktop
                      SizedBox(
                        width: 400,
                        child: Column(
                          children: [
                            scannerSection,
                            const Spacer(),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.divider),
                      Expanded(
                        child: Column(
                          children: [
                            cartList,
                            checkoutFooter,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Single column stack for phone
          return Column(
            children: [
              scannerSection,
              voiceSearchBar,
              cartList,
              checkoutFooter,
            ],
          );
        },
      ),
    );
  }
}

class _VoiceSearchBar extends StatefulWidget {
  final bool isVisible;
  final bool isListening;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDiscard;
  final VoidCallback onConfirm;

  const _VoiceSearchBar({
    required this.isVisible,
    required this.isListening,
    required this.controller,
    required this.focusNode,
    required this.onDiscard,
    required this.onConfirm,
  });

  @override
  State<_VoiceSearchBar> createState() => _VoiceSearchBarState();
}

class _VoiceSearchBarState extends State<_VoiceSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  Widget _buildSuffixIcon() {
    final hasText = widget.controller.text.isNotEmpty;

    if (widget.isListening) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.highlightActive,
          ),
        ),
      );
    }

    if (hasText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              LucideIcons.search,
              color: AppColors.primaryDark,
              size: 18,
            ),
            onPressed: widget.onConfirm,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.x,
              color: AppColors.secondaryAccent,
              size: 18,
            ),
            onPressed: widget.onDiscard,
            tooltip: 'Discard',
          ),
        ],
      );
    }

    return IconButton(
      icon: const Icon(
        LucideIcons.x,
        color: AppColors.secondaryAccent,
        size: 18,
      ),
      onPressed: widget.onDiscard,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 72.0,
          color: AppColors.primaryDark.withValues(alpha: 0.8),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.highlightActive.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isListening ? 'Listening...' : 'Edit and tap search...',
                    hintStyle: TextStyle(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.mic,
                      color: AppColors.primaryDark,
                    ),
                    suffixIcon: _buildSuffixIcon(),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => widget.onConfirm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LowStockStandaloneScreen extends StatefulWidget {
  const LowStockStandaloneScreen({super.key});

  @override
  State<LowStockStandaloneScreen> createState() =>
      _LowStockStandaloneScreenState();
}

class _LowStockStandaloneScreenState extends State<LowStockStandaloneScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const PosDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.menu,
            color: AppColors.white,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Low Stock',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: const LowStockScreen(),
    );
  }
}

class ExpiringSoonStandaloneScreen extends StatefulWidget {
  const ExpiringSoonStandaloneScreen({super.key});

  @override
  State<ExpiringSoonStandaloneScreen> createState() =>
      _ExpiringSoonStandaloneScreenState();
}

class _ExpiringSoonStandaloneScreenState
    extends State<ExpiringSoonStandaloneScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const PosDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.menu,
            color: AppColors.white,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Expiring Soon',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: const ExpiringSoonScreen(),
    );
  }
}

class SalesReportStandaloneScreen extends StatefulWidget {
  const SalesReportStandaloneScreen({super.key});

  @override
  State<SalesReportStandaloneScreen> createState() =>
      _SalesReportStandaloneScreenState();
}

class _SalesReportStandaloneScreenState
    extends State<SalesReportStandaloneScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const PosDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.menu,
            color: AppColors.white,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Sales Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: const SalesReportScreen(),
    );
  }
}

