import 'dart:io';
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
  bool _isCameraActive = true;

  // Voice search state
  bool _isVoiceSearchActive = false;
  bool _isListeningVoice = false;
  final TextEditingController _voiceSearchController = TextEditingController();
  final FocusNode _voiceSearchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
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
    if (!_isCameraActive) return;

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
        return Dialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.secondaryAccent, width: 4),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess ? LucideIcons.checkCircle2 : LucideIcons.trash2,
                      size: 80,
                      color: isSuccess ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSuccess ? 'Sale Complete' : 'Clear Cart?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (type == 'clear')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primaryDark,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<POSProvider>().clearCart();
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Yes, Clear',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
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
                              // Show success dialog with invoice number
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sale Complete! Invoice: $invoiceNumber',
                                    ),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'New Sale',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.primaryDark),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
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
    if (wasOn) _cameraController.stop();
    await navigate();
    if (wasOn && mounted) _cameraController.start();
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
      if (wasOn && mounted) _cameraController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<POSProvider>();
    final cart = posProvider.cart;
    final filteredCart = posProvider.filteredCart;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      drawer: PosDrawer(onNavigate: _navigateFromDrawer),
      body: SafeArea(
        child: Stack(
          children: [
            // BASE LAYER: main content Column
            Column(
              children: [
                // 1. HEADER
                Container(
                  color: AppColors.primaryDark,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(
                              LucideIcons.menu,
                              color: AppColors.white,
                            ),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. SCANNER SECTION
                PosScannerSection(
                  cameraController: _cameraController,
                  scanAnimation: _scanAnimation,
                  isTablet: isTablet,
                  isCameraActive: _isCameraActive,
                  isProcessingScan: _isProcessingScan,
                  onBarcodeScanned: (code) =>
                      _handleBarcodeScan(code, posProvider),
                  onToggleCamera: () {
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
                    if (wasOn) _cameraController.stop();

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManualAddScreen(),
                      ),
                    );

                    if (wasOn && mounted) {
                      _cameraController.start();
                    }
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
                ),

                // 2b. VOICE SEARCH BAR (slides in when active)
                _VoiceSearchBar(
                  isVisible: _isVoiceSearchActive,
                  isListening: _isListeningVoice,
                  controller: _voiceSearchController,
                  focusNode: _voiceSearchFocus,
                  onDiscard: _stopHomeVoiceSearch,
                  onConfirm: () =>
                      _handleHomeFinalSpeech(posProvider, _voiceSearchController.text),
                ),

                // 3. CART LIST
                PosCartList(
                  cart: cart,
                  filteredCart: filteredCart,
                  provider: posProvider,
                ),

                // 4. CHECKOUT FOOTER
                PosCheckoutFooter(
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
                            message:
                                'Successfully charged ${posProvider.calculateTotal.toStringAsFixed(2)} Taka',
                          );
                        },
                      );
                    } else {
                      _showModal(
                        type: 'success',
                        message:
                            'Successfully charged ${posProvider.calculateTotal.toStringAsFixed(2)} Taka',
                      );
                    }
                  },
                ),
              ], // end inner Column children
            ), // end inner Column
          ], // end Stack children
        ), // end Stack
      ), // end SafeArea
    ); // end Scaffold
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: widget.isVisible ? 72.0 : 0.0,
      color: AppColors.primaryDark,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.highlightActive, width: 2),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.isListening
                    ? 'Listening...'
                    : 'Edit and tap search...',
                hintStyle: TextStyle(
                  color: AppColors.secondaryAccent.withValues(alpha: 0.7),
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

