import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/colors.dart';
import '../providers/pos_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/language_provider.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/database_helper.dart';
import '../services/ocr_service.dart';
import '../services/strip_ai_model_store.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/time_service.dart';
import '../navigation/app_route_observer.dart';
import '../services/mobile_scanner_bridge.dart';
import '../config/api_config.dart';
import '../widgets/home/out_of_stock_dialog.dart';
import '../widgets/home/pos_scanner_section.dart';
import '../widgets/home/pos_cart_list.dart';
import '../widgets/home/pos_checkout_footer.dart';
import '../widgets/home/pos_quick_actions.dart';
import 'admin/expiring_soon_screen.dart';
import 'admin/low_stock_screen.dart';
import 'admin/sales_report_screen.dart';
import 'manual_add_screen.dart';
import 'ocr_scan_result_screen.dart';
import 'login_screen.dart';
import '../widgets/drawer/pos_drawer.dart';
import '../services/continuous_voice_session_service.dart';
import '../utils/product_matcher.dart';
import '../widgets/subscription_warning_dialog.dart';
import '../widgets/taka_symbol.dart';
import 'subscription_screen.dart';
import 'admin/notification_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? replacementSourceInvoiceNumber;

  const HomeScreen({
    super.key,
    this.replacementSourceInvoiceNumber,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scanScrollController = ScrollController();
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  // Scanner variables
  late MobileScannerController _cameraController;
  bool _isProcessingScan = false;
  late bool _isCameraActive;

  // Scanner starts expanded so users immediately see camera/paused state.
  bool _isScannerExpanded = true;
  bool _isTopSectionCollapsed = false;

  // Voice search state
  bool _isVoiceSearchActive = false;
  bool _isListeningVoice = false;
  late final ContinuousVoiceSessionService _homeVoiceSession;
  final TextEditingController _voiceSearchController = TextEditingController();
  final FocusNode _voiceSearchFocus = FocusNode();

  // Inline search state
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isCheckingSubscriptionStatus = false;
  final AuthStorage _authStorage = const AuthStorage();
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchFieldKey = GlobalKey();
  OverlayEntry? _searchOverlay;
  List<Product> _searchSuggestions = [];
  bool _replacementCheckoutCommitted = false;
  int _homeSeenReplacementFlowVersion = 0;
  static const int _ocrMaxImageWidth = 1280;
  static const int _ocrJpegQuality = 75;
  static const String _ocrTempDirName = 'ocr_temp';

  /// False while another [PageRoute] sits above Home (drawer pushes, dialogs
  /// as routes, etc.); keeps the barcode camera released when not visible.
  bool _homeRouteOnTop = true;

  /// OCR / native camera picker: [showDialog] routes would otherwise call
  /// [didPopNext] and restart the barcode scanner before this flow finishes.
  int _blockingBarcodeCameraWorkflowDepth = 0;

  /// Provider-driven replacement (Returns flow) or legacy widget argument.
  String? _replacementInvoiceForFlow(POSProvider pos) {
    final p = pos.replacementSourceInvoiceNumber?.trim();
    if (p != null && p.isNotEmpty) return p;
    final w = widget.replacementSourceInvoiceNumber?.trim();
    if (w != null && w.isNotEmpty) return w;
    return null;
  }

  /// Starts or stops the POS barcode camera from a single set of rules: route
  /// visibility, app lifecycle, user toggle, and scanner expanded state.
  void _syncHomeScannerVisibility() {
    if (!mounted || Platform.isWindows) return;
    if (_blockingBarcodeCameraWorkflowDepth > 0) {
      if (_cameraController.value.isRunning) {
        unawaited(_cameraController.stop());
      }
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final inForeground = lifecycle == null ||
        lifecycle == AppLifecycleState.resumed;
    final wantRunning = _isCameraActive &&
        _isScannerExpanded &&
        _homeRouteOnTop &&
        inForeground;

    if (!wantRunning) {
      if (_cameraController.value.isRunning) {
        unawaited(_cameraController.stop());
      }
      return;
    }
    if (!_cameraController.value.isRunning) {
      unawaited(_cameraController.start());
    }
  }

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

    _homeVoiceSession = ContinuousVoiceSessionService(
      onTranscript: (text, {required isFinal}) {
        if (!mounted) return;
        setState(() {
          _voiceSearchController.text = text;
          _voiceSearchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _voiceSearchController.text.length),
          );
        });
      },
      onFinalTranscript: (text) async {
        if (!mounted) return;
        _handleHomeFinalSpeech(context.read<POSProvider>(), text);
      },
      onError: (error) {
        if (!mounted || error.isEmpty) return;
        final l10n = context.read<LanguageProvider>().strings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.voiceError(error),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
      onStateChanged: () {
        if (!mounted) return;
        setState(() {
          _isVoiceSearchActive = _homeVoiceSession.isActive;
          _isListeningVoice = _homeVoiceSession.isListening;
        });
      },
    );

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceSubscriptionBlockIfNeeded();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await context.read<AdminProvider>().refreshActiveSellerFromServer();
      } on SessionExpiredException {
        if (!mounted) return;
        _redirectToLogin();
        return;
      }
      if (mounted) setState(() {});
    });

    MobileScannerBridge.register(
      pauseBackgroundScanner: _pauseScannerForOverlay,
      resumeBackgroundScanner: _resumeScannerAfterOverlay,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
    final v = context.read<POSProvider>().replacementFlowVersion;
    if (v != _homeSeenReplacementFlowVersion) {
      _homeSeenReplacementFlowVersion = v;
      _replacementCheckoutCommitted = false;
    }
  }

  @override
  void didPush() {
    _homeRouteOnTop = true;
    _syncHomeScannerVisibility();
  }

  @override
  void didPopNext() {
    _homeRouteOnTop = true;
    _syncHomeScannerVisibility();
  }

  @override
  void didPushNext() {
    _homeRouteOnTop = false;
    _syncHomeScannerVisibility();
  }

  @override
  void didPop() {
    _homeRouteOnTop = false;
    _syncHomeScannerVisibility();
  }

  Future<void> _pauseScannerForOverlay() async {
    if (Platform.isWindows) return;
    if (_cameraController.value.isRunning) {
      await _cameraController.stop();
    }
  }

  void _resumeScannerAfterOverlay() {
    _syncHomeScannerVisibility();
  }

  Future<void> _toggleScannerExpanded() async {
    if (_isScannerExpanded) {
      if (!Platform.isWindows) {
        await _cameraController.stop();
      }
    }
    if (!mounted) return;
    setState(() => _isScannerExpanded = !_isScannerExpanded);
    _syncHomeScannerVisibility();
  }

  void _redirectToLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session expired. Please log in again.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _enforceSubscriptionBlockIfNeeded() async {
    final session = await _authStorage.loadAuth();
    if (!mounted || session == null) return;
    final rootNavigator = Navigator.of(context);

    final expiresAt = DateTime.tryParse(session.subscriptionValidUntil.trim());
    final reliableNow = await TimeService().getReliableNow();
    if (!mounted) return;
    final isExpired = expiresAt != null && expiresAt.isBefore(reliableNow);
    if (!isExpired) return;

    // Block if SharedPreferences says inactive OR if JWT claim says expired
    // (guards against SharedPreferences tampering on rooted devices).
    final jwtExpired = _authStorage.isJwtSubscriptionExpired(
      session.licenseToken,
      reliableNow,
    );
    if (session.isActive && !jwtExpired) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Subscription expired'),
            content: const Text(
              'Your subscription has expired. Renew now to continue using the app.',
            ),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Exit'),
              ),
              TextButton(
                onPressed: _isCheckingSubscriptionStatus
                    ? null
                    : () async {
                        setState(() => _isCheckingSubscriptionStatus = true);
                        final isActive = await _refreshSubscriptionStatusFromServer(
                          showFeedback: true,
                        );
                        if (!mounted || !ctx.mounted) return;
                        setState(() => _isCheckingSubscriptionStatus = false);
                        if (isActive == true) {
                          Navigator.of(ctx).pop();
                        }
                      },
                child: _isCheckingSubscriptionStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check Status'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  rootNavigator.pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(
                        pharmacyId: session.pharmacyId,
                        isDismissible: false,
                      ),
                    ),
                  );
                },
                child: const Text('Renew'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSubscriptionFromServer();
    }
    _syncHomeScannerVisibility();
  }

  /// Calls [check_access.php] when the app returns to foreground.
  /// Server status is written to cache and block UI is re-applied if inactive.
  Future<void> _syncSubscriptionFromServer() async {
    final isActive = await _refreshSubscriptionStatusFromServer(
      showFeedback: false,
    );
    if (!mounted) return;
    if (isActive == false) {
      _enforceSubscriptionBlockIfNeeded();
    }
  }

  Future<void> _handleHomeSwipeRefresh() async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.refreshActiveSellerFromServer();
      await admin.loadPharmacyDevices();
    } on SessionExpiredException {
      if (!mounted) return;
      _redirectToLogin();
      return;
    }
    if (mounted) setState(() {});
  }

  Future<bool?> _refreshSubscriptionStatusFromServer({
    required bool showFeedback,
  }) async {
    final session = await _authStorage.loadAuth();
    if (!mounted || session == null || session.licenseToken.isEmpty) return null;

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/check_access.php'),
            headers: {'Authorization': 'Bearer ${session.licenseToken}'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not verify subscription right now.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final serverIsActive = (data['is_active'] as int?) == 1;
      final serverValidUntil = (data['valid_until'] as String?) ?? '';

      await _authStorage.updateSubscriptionStatus(
        isActive: serverIsActive,
        validUntil: serverValidUntil.isNotEmpty
            ? serverValidUntil
            : session.subscriptionValidUntil,
      );

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverIsActive
                  ? 'Subscription is active now.'
                  : 'Subscription is still inactive.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor:
                serverIsActive ? Colors.green.shade700 : AppColors.error,
          ),
        );
      }

      return serverIsActive;
    } catch (_) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Network error while checking subscription.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    MobileScannerBridge.unregister();
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimationController.dispose();
    _scanScrollController.dispose();
    _cameraController.dispose();
    _homeVoiceSession.dispose();
    _voiceSearchController.dispose();
    _voiceSearchFocus.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _removeSearchOverlay();
    super.dispose();
  }

  // ── Inline search ────────────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchSuggestions = [];
        _removeSearchOverlay();
        _searchFocus.unfocus();
      }
    });
    if (_isSearchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocus.requestFocus();
      });
    }
  }

  void _onSearchChanged(String query, POSProvider posProvider) {
    if (query.trim().isEmpty) {
      setState(() => _searchSuggestions = []);
      _removeSearchOverlay();
      return;
    }
    final q = query.toLowerCase();
    final results = posProvider.products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.generic.toLowerCase().contains(q))
        .take(6)
        .toList();
    setState(() => _searchSuggestions = results);
    if (results.isEmpty) {
      _removeSearchOverlay();
    } else if (_searchOverlay == null) {
      _insertSearchOverlay(posProvider);
    } else {
      _searchOverlay!.markNeedsBuild();
    }
  }

  double _getSearchFieldWidth() {
    final rb =
        _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb != null && rb.hasSize) return rb.size.width;
    // Fallback: screen width minus the 12+12 horizontal padding of the search bar
    return MediaQuery.of(context).size.width - 24.0;
  }

  void _insertSearchOverlay(POSProvider posProvider) {
    final overlayState = Overlay.of(context);
    _searchOverlay = OverlayEntry(
      builder: (ctx) {
        final pos = Provider.of<POSProvider>(ctx, listen: false);
        final l10n = Provider.of<LanguageProvider>(ctx, listen: false).strings;
        // Cap the dropdown height so it never extends behind the keyboard.
        // Using viewInsets.bottom to detect keyboard height.
        final mq = MediaQuery.of(ctx);
        final availableHeight =
            mq.size.height - mq.viewInsets.bottom - mq.padding.top - 64 - 60;
        final maxDropdownHeight = (availableHeight * 0.55).clamp(120.0, 320.0);

        return CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              color: AppColors.white,
              child: SizedBox(
                width: _getSearchFieldWidth(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxDropdownHeight),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _searchSuggestions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (_, idx) {
                      final p = _searchSuggestions[idx];
                      return InkWell(
                        onTap: () {
                          pos.updatePcQuantity(p, 1);
                          _removeSearchOverlay();
                          setState(() {
                            _isSearchVisible = false;
                            _searchController.clear();
                            _searchSuggestions = [];
                          });
                          _searchFocus.unfocus();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${l10n.addedToCart.replaceFirst('{name}', p.name)}${l10n.onePcSuffix}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.pill,
                                  size: 15,
                                  color: AppColors.secondaryAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.primaryDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    if (p.generic.isNotEmpty)
                                      Text(
                                        p.generic,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryAccent
                                              .withValues(alpha: 0.8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${p.pricePc.toStringAsFixed(p.pricePc % 1 == 0 ? 0 : 1)}৳',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(_searchOverlay!);
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  // ── Voice search ─────────────────────────────────────────────────────────

  Future<void> _startHomeVoiceSearch() async {
    await _homeVoiceSession.start(clearTranscript: true);
  }

  Future<void> _stopHomeVoiceSearch() async {
    await _homeVoiceSession.stop(clearTranscript: true);
  }

  void _handleHomeFinalSpeech(POSProvider posProvider, String text) {
    final l10n = context.read<LanguageProvider>().strings;
    final best = ProductMatcher.findBestMatch(text, posProvider.products);

    if (best != null) {
      posProvider.updatePcQuantity(best.product, 1);
      // Ensure stale search from other screens does not hide new cart rows.
      posProvider.setSearchQuery('');
      setState(() {
        _voiceSearchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.addedToCart.replaceFirst('{name}', best.product.name)}${l10n.onePcSuffix}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.noMatchVoice,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showClearCartDialog() {
    final l10n = context.read<LanguageProvider>().strings;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final screenWidth = MediaQuery.of(ctx).size.width;
        final isNarrow = screenWidth < 380;
        final iconSize = isNarrow ? 60.0 : 72.0;

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          icon: Icon(
            LucideIcons.trash2,
            size: iconSize,
            color: AppColors.error,
          ),
          title: Text(
            l10n.clearCart,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          content: Text(
            l10n.clearCartConfirm,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancelBtn),
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
              child: Text(l10n.yesClr),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeCheckoutSale() async {
    final pos = context.read<POSProvider>();
    final admin = context.read<AdminProvider>();
    final l10n = context.read<LanguageProvider>().strings;
    final saleTotal = pos.calculateTotal;

    try {
      final repl = _replacementInvoiceForFlow(pos);
      if (repl != null) {
        await pos.completeReplacementSale(repl);
      } else {
        await pos.completeSale();
      }
      await admin.refreshSales();
      await admin.loadData();
      _replacementCheckoutCommitted = true;
    } on InactiveSellingDeviceException catch (_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await admin.refreshActiveSellerFromServer();
      } on SessionExpiredException {
        if (!mounted) return;
        _redirectToLogin();
        return;
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.checkoutRequiresActiveDevice,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } on SessionExpiredException {
      if (!mounted) return;
      _redirectToLogin();
      return;
    } catch (e, st) {
      debugPrint('Checkout failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.checkoutFailed,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SaleCompleteAutoCloseDialog(saleTotal: saleTotal),
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

  // ── Barcode scan ──────────────────────────────────────────────────────────

  Future<void> _handleBarcodeScan(
    String code,
    POSProvider posProvider,
  ) async {
    final l10n = context.read<LanguageProvider>().strings;
    if (!_isCameraActive || _isProcessingScan) return;

    setState(() => _isProcessingScan = true);

    bool success = false;
    if (mounted) {
      success = await posProvider.handleBarcodeScan(code);
    }
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.barcodeNotFound}: $code'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 0),
        ),
      );
    }

    if (mounted) {
      setState(() => _isProcessingScan = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _navigateFromDrawer(Future<void> Function() navigate) async {
    if (!context.mounted) return;
    Navigator.pop(context);
    await navigate();
    if (mounted) _syncHomeScannerVisibility();
  }

  Future<void> _handleManualAdd({String? genericFilter}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualAddScreen(initialGenericFilter: genericFilter),
      ),
    );
    if (mounted) _syncHomeScannerVisibility();
  }

  Future<void> _handleOcrScan() async {
    _blockingBarcodeCameraWorkflowDepth++;
    final l10n = context.read<LanguageProvider>().strings;
    final bool canStop = _isCameraActive && _isScannerExpanded;
    if (canStop) _cameraController.stop();

    bool loadingDialogOpen = false;

    try {
      debugPrint('[OCR] camera flow: opening picker');
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (file == null) {
        debugPrint('[OCR] camera flow: user cancelled picker');
        return;
      }

      if (!context.mounted) return;

      loadingDialogOpen = true;
      debugPrint('[OCR] camera flow: showing loading dialog');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            color: AppColors.white,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primaryDark),
                  const SizedBox(height: 16),
                  Text(
                    l10n.readingStrip,
                    style: const TextStyle(
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

      debugPrint('[OCR] camera flow: preprocessing ${file.path}');
      final sw = Stopwatch()..start();
      final imageFile = await _preprocessImageForOcr(File(file.path));
      debugPrint(
        '[OCR] camera flow: preprocess done in ${sw.elapsedMilliseconds}ms → ${imageFile.path}',
      );
      await _handleOcrImageFile(imageFile);
      debugPrint('[OCR] camera flow: handleOcrImageFile finished');
    } catch (e, st) {
      debugPrint('[OCR] camera flow ERROR: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(l10n.ocrError(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (loadingDialogOpen && context.mounted) {
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) {
          debugPrint('[OCR] camera flow: dismissing loading dialog');
          nav.pop();
        }
        loadingDialogOpen = false;
      }
      _blockingBarcodeCameraWorkflowDepth--;
      if (context.mounted) _syncHomeScannerVisibility();
    }
  }

  Future<void> _handleOcrScanFromGallery() async {
    _blockingBarcodeCameraWorkflowDepth++;
    final bool canStop = _isCameraActive && _isScannerExpanded;
    if (canStop) _cameraController.stop();
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (file == null) return;
      final imageFile = await _preprocessImageForOcr(File(file.path));
      await _handleOcrImageFile(imageFile);
    } catch (e) {
      if (!context.mounted) return;
      final l10n = context.read<LanguageProvider>().strings;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.ocrError(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      _blockingBarcodeCameraWorkflowDepth--;
      if (context.mounted) _syncHomeScannerVisibility();
    }
  }

  Future<void> _handleOcrImageFile(File imageFile) async {
    if (!context.mounted) return;
    final l10n = context.read<LanguageProvider>().strings;
    final products = context.read<POSProvider>().products;
    final useStripAi = await StripAiModelStore.instance.isInstalled();
    if (!context.mounted) return;
    debugPrint(
      '[OCR] process start path=${imageFile.path} stripAi=$useStripAi products=${products.length}',
    );
    final sw = Stopwatch()..start();
    final results = await OcrService.process(
      imageFile,
      products,
      fetchCandidatesForOcr: (t) => DatabaseHelper().getCandidatesForOcr(t),
      useStripAiModel: useStripAi,
    );
    debugPrint(
      '[OCR] process done in ${sw.elapsedMilliseconds}ms results=${results.length}',
    );
    if (!context.mounted) return;
    if (results.isEmpty) {
      await _deleteIfAppManagedOcrFile(imageFile);
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.noMedicineDetected),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }
    if (!context.mounted) return;
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
  }

  Future<void> _deleteIfAppManagedOcrFile(File file) async {
    final filePath = p.normalize(file.absolute.path);
    if (p.basename(p.dirname(filePath)) != _ocrTempDirName) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      final tempOcrRoot = p.normalize(p.join(tempDir.path, _ocrTempDirName));
      final docsOcrRoot = p.normalize(p.join(docsDir.path, _ocrTempDirName));
      final isManaged =
          p.isWithin(tempOcrRoot, filePath) || p.isWithin(docsOcrRoot, filePath);
      if (!isManaged) return;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final posProvider = context.watch<POSProvider>();
    final cart = posProvider.cart;
    // Home cart should always reflect the full cart; filtering belongs to Manual Add.
    final filteredCart = cart;

    // Subscription warning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (adminProvider.pendingSubWarningDays != null) {
        final days = adminProvider.pendingSubWarningDays!;
        adminProvider.clearPendingWarning();

        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => SubscriptionWarningDialog(
            daysRemaining: days,
            onRenew: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubscriptionScreen(
                    pharmacyId: adminProvider.authSession?.pharmacyId ?? '',
                    isDismissible: true,
                  ),
                ),
              );
            },
            onDismiss: () => Navigator.pop(ctx),
          ),
        );
      }
    });

    // Shared widgets
    Widget expandableSearch = _ExpandableSearchBar(
      isVisible: _isSearchVisible,
      controller: _searchController,
      focusNode: _searchFocus,
      layerLink: _searchLayerLink,
      fieldKey: _searchFieldKey,
      onChanged: (q) => _onSearchChanged(q, posProvider),
      onClose: _toggleSearch,
    );

    Widget quickActionsPanel = PosQuickActions(
      isScannerExpanded: _isScannerExpanded,
      onToggleScanner: () {
        unawaited(_toggleScannerExpanded());
      },
      onManualAdd: _handleManualAdd,
      onOcrScan: _handleOcrScan,
      onOcrScanLongPress: _handleOcrScanFromGallery,
      onVoiceTap: () {
        if (_isVoiceSearchActive) {
          _stopHomeVoiceSearch();
        } else {
          _startHomeVoiceSearch();
        }
      },
      isVoiceActive: _isVoiceSearchActive,
      isPanelMode: true,
    );

    Widget scannerSection = PosScannerSection(
      cameraController: _cameraController,
      scanAnimation: _scanAnimation,
      isTablet: false,
      isCameraActive: _isCameraActive,
      isProcessingScan: _isProcessingScan,
      onBarcodeScanned: (code) => _handleBarcodeScan(code, posProvider),
      onToggleCamera: () {
        if (Platform.isWindows) return;
        setState(() {
          _isCameraActive = !_isCameraActive;
        });
        _syncHomeScannerVisibility();
      },
      isExpanded: _isScannerExpanded,
      onToggleExpanded: () {
        unawaited(_toggleScannerExpanded());
      },
    );

    Widget voiceSearchBar = _VoiceSearchBar(
      isVisible: _isVoiceSearchActive,
      isListening: _isListeningVoice,
      controller: _voiceSearchController,
      focusNode: _voiceSearchFocus,
      onDiscard: _stopHomeVoiceSearch,
      onConfirm: () =>
          _handleHomeFinalSpeech(posProvider, _voiceSearchController.text),
    );

    Widget cartList = PosCartList(
      cart: cart,
      filteredCart: filteredCart,
      provider: posProvider,
      onGenericTap: (generic) => _handleManualAdd(genericFilter: generic),
      onSwipeLeft: _handleManualAdd,
      onSwipeRight: () => _scaffoldKey.currentState?.openDrawer(),
    );

    final canSell = adminProvider.isCurrentDeviceActiveSeller;

    Widget checkoutFooter = PosCheckoutFooter(
      cart: cart,
      total: posProvider.calculateTotal,
      onClear: _showClearCartDialog,
      onCheckout: !canSell
          ? null
          : () {
              if (_isAnyItemOutOfStock(cart)) {
                _showStockWarning(context, _completeCheckoutSale);
              } else {
                _completeCheckoutSale();
              }
            },
    );

    final replacementInv = _replacementInvoiceForFlow(posProvider);
    return PopScope(
      canPop: replacementInv == null || _replacementCheckoutCommitted,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final pos = context.read<POSProvider>();
        final repl = _replacementInvoiceForFlow(pos);
        if (repl != null && !_replacementCheckoutCommitted) {
          if (pos.replacementReturnToAdminOnBack) {
            pos.clearCart();
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminDashboardScreen(
                    initialNavIndex: AdminDashboardScreen.returnsNavIndex,
                  ),
                ),
              );
            }
            return;
          }
          pos.clearCart();
        }
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.posBackground,
        resizeToAvoidBottomInset: false,
        drawer: PosDrawer(onNavigate: _navigateFromDrawer),
        appBar: _buildGradientAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
          const double rightPanelWidth = 80;
          // Cap the scanner+buttons content to 30% of body height
          final double topContentHeight =
              (constraints.maxHeight * 0.30).clamp(140.0, 230.0);

          return Column(
            children: [
              expandableSearch,
              // ── Collapsible top card ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Toggle header ──────────────────────────────
                      InkWell(
                        onTap: () => setState(() =>
                            _isTopSectionCollapsed = !_isTopSectionCollapsed),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.secondaryAccent,
                                AppColors.primaryDark,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.scan,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Scanner & Actions',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Icon(
                                _isTopSectionCollapsed
                                    ? LucideIcons.chevronDown
                                    : LucideIcons.chevronUp,
                                size: 14,
                                color: Colors.white60,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ── Scanner + buttons content ──────────────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: _isTopSectionCollapsed
                            ? const SizedBox.shrink()
                            : SizedBox(
                                height: topContentHeight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: scannerSection),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: rightPanelWidth,
                                        child: quickActionsPanel,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              voiceSearchBar,
              // ── Cart list (always visible) ─────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleHomeSwipeRefresh,
                  child: cartList,
                ),
              ),
              // ── Checkout footer (always visible) ──────────────────────────
              checkoutFooter,
            ],
          );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGradientAppBar() {
    final l10n = context.watch<LanguageProvider>().strings;
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondaryAccent, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(LucideIcons.menu, color: AppColors.white),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: l10n.menuTooltip,
      ),
      title: Text(
        l10n.posTitle,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? LucideIcons.x : LucideIcons.search,
            color: AppColors.white,
          ),
          onPressed: _toggleSearch,
          tooltip: _isSearchVisible ? l10n.closeSearchTooltip : l10n.searchTooltip,
        ),
        Builder(
          builder: (context) {
            final admin = context.watch<AdminProvider>();
            final alertCount = admin.unreadAlertCount;
            final l10n = context.watch<LanguageProvider>().strings;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.bell, color: AppColors.white),
                  tooltip: l10n.alertsTooltip,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationScreen()),
                    );
                  },
                ),
                if (alertCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$alertCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Expandable Search Bar ──────────────────────────────────────────────────

class _ExpandableSearchBar extends StatelessWidget {
  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final GlobalKey fieldKey;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _ExpandableSearchBar({
    required this.isVisible,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.fieldKey,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: isVisible ? 60.0 : 0.0,
      color: AppColors.primaryDark,
      child: isVisible
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: CompositedTransformTarget(
                link: layerLink,
                child: Container(
                  key: fieldKey,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.highlightActive.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      hintStyle: TextStyle(
                        color: AppColors.secondaryAccent.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        color: AppColors.secondaryAccent,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.x,
                            size: 16, color: AppColors.secondaryAccent),
                        onPressed: onClose,
                        tooltip: l10n.closeSearchTooltip,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Voice Search Bar ───────────────────────────────────────────────────────

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
    final l10n = context.read<LanguageProvider>().strings;
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
            tooltip: l10n.searchBtnTooltip,
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.x,
              color: AppColors.secondaryAccent,
              size: 18,
            ),
            onPressed: widget.onDiscard,
            tooltip: l10n.discardBtnTooltip,
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
    final l10n = context.watch<LanguageProvider>().strings;
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
                    hintText:
                        widget.isListening ? l10n.listening : l10n.voiceSearchHint,
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
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

class _SaleCompleteAutoCloseDialog extends StatefulWidget {
  const _SaleCompleteAutoCloseDialog({required this.saleTotal});

  final double saleTotal;

  @override
  State<_SaleCompleteAutoCloseDialog> createState() =>
      _SaleCompleteAutoCloseDialogState();
}

class _SaleCompleteAutoCloseDialogState
    extends State<_SaleCompleteAutoCloseDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    final amountSize = isNarrow ? 36.0 : 44.0;
    final takaSize = isNarrow ? 34.0 : 42.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      icon: Icon(
        LucideIcons.checkCircle2,
        size: isNarrow ? 60.0 : 72.0,
        color: AppColors.success,
      ),
      title: Text(
        l10n.saleComplete,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDark,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.totalPayable,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryAccent,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TakaSymbol(
                size: takaSize,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                widget.saleTotal.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: amountSize,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Standalone screens (unchanged) ────────────────────────────────────────

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
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const PosDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(LucideIcons.menu, color: AppColors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          l10n.lowStockTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
      ),
      body: const LowStockScreen(showAppBar: false),
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
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const PosDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(LucideIcons.menu, color: AppColors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
         title: Text(
          l10n.expiringSoonTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
      ),
      body: const ExpiringSoonScreen(showAppBar: false),
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
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const PosDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(LucideIcons.menu, color: AppColors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          l10n.salesReport,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
      ),
      body: const SalesReportScreen(),
    );
  }
}
