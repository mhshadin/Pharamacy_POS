import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/colors.dart';
import '../utils/api_error_mapper.dart';
import '../services/eps_service.dart';
import '../services/auth_service.dart';
import '../services/auth_storage.dart';
import '../widgets/plan_card.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final String pharmacyId;
  final bool isDismissible;

  const SubscriptionScreen({
    super.key,
    required this.pharmacyId,
    this.isDismissible = true,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _epsService = const EpsService();
  final _couponController = TextEditingController();

  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  String? _selectedPlanId;
  bool _isMonthly = true;
  bool _isProcessing = false;
  
  // Coupon state
  Map<String, dynamic>? _appliedCoupon;
  bool _isValidatingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _epsService.getPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
          if (_plans.isNotEmpty) {
            _selectedPlanId = _plans.first['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorMapper.forPlanLoad()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleApplyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
      _appliedCoupon = null;
    });

    try {
      final coupon = await _epsService.validateCoupon(code);
      if (mounted) {
        setState(() {
          _appliedCoupon = coupon;
          _isValidatingCoupon = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LanguageProvider>().strings.couponApplied),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _couponError = e.toString().contains('Exception:') 
              ? e.toString().split('Exception:').last.trim() 
              : context.read<LanguageProvider>().strings.invalidCoupon;
          _isValidatingCoupon = false;
        });
      }
    }
  }

  double _calculatePayableAmount(double originalPrice) {
    if (_appliedCoupon == null) return originalPrice;
    
    final discountPercent = (_appliedCoupon!['discount_percent'] as num?)?.toDouble() ?? 0.0;
    if (discountPercent <= 0) return originalPrice;
    
    final discountAmount = originalPrice * (discountPercent / 100);
    final finalPrice = originalPrice - discountAmount;
    return finalPrice < 0 ? 0 : finalPrice;
  }

  Future<void> _refreshSessionAfterRenewal() async {
    try {
      const storage = AuthStorage();
      final session = await storage.loadAuth();
      if (session == null || session.refreshToken.isEmpty) return;
      final result = await const AuthService().refreshJwtToken(session.refreshToken);
      await storage.saveAuth(result);
    } catch (_) {
      // Non-fatal: user proceeds to home; worst case they re-login
    }
  }

  void _handleBuyNow() async {
    if (_selectedPlanId == null) return;

    final l10n = context.read<LanguageProvider>().strings;
    final selectedPlan = _plans.firstWhere((p) => p['id'] == _selectedPlanId);
    final originalPrice = (selectedPlan['price'] as num).toDouble();
    final payableAmount = _calculatePayableAmount(originalPrice);

    setState(() {
      _isProcessing = true;
    });

    try {
      // Logic for 100% Free or 0-amount discount
      final hasFreeDays = (_appliedCoupon?['free_days'] as num?) != null && (_appliedCoupon!['free_days'] as num) > 0;
      
      if (hasFreeDays || payableAmount <= 0) {
        final success = await _epsService.applyFreeCoupon(
          pharmacyId: widget.pharmacyId,
          planId: _selectedPlanId!,
          couponCode: _appliedCoupon?['code'] ?? _couponController.text.trim(),
        );

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(hasFreeDays 
                ? l10n.freeDaysAdded((_appliedCoupon!['free_days'] as num).toInt())
                : l10n.success),
              backgroundColor: Colors.green.shade700,
            ),
          );
          await _refreshSessionAfterRenewal();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          return;
        } else {
          throw Exception('Failed to apply coupon');
        }
      }

      // Standard payment flow
      final result = await _epsService.initializePayment(
        pharmacyId: widget.pharmacyId,
        planId: _selectedPlanId!,
        couponCode: _appliedCoupon?['code'],
      );

      if (!mounted) return;

      // Open WebView
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => EpsWebViewScreen(
            url: result.redirectUrl,
            merchantTransactionId: result.merchantTransactionId,
          ),
        ),
      );

      if (success == true) {
        await _refreshSessionAfterRenewal();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorMapper.forPaymentInit()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final filteredPlans = _plans
        .where(
          (p) => _isMonthly
              ? p['billing_cycle'] == 'monthly'
              : p['billing_cycle'] == 'yearly',
        )
        .toList();

    final selectedPlan = _selectedPlanId != null 
        ? _plans.firstWhere((p) => p['id'] == _selectedPlanId, orElse: () => _plans.first)
        : null;
    final originalPrice = selectedPlan != null ? (selectedPlan['price'] as num).toDouble() : 0.0;
    final payableAmount = _calculatePayableAmount(originalPrice);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    context.watch<LanguageProvider>().strings.elevatePharmacy,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.watch<LanguageProvider>().strings.choosePlanDesc,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Billing Toggle
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleButton(l10n.monthlyBilling, _isMonthly),
                          _buildToggleButton(l10n.yearlySave20, !_isMonthly),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Plans Carousel
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    SizedBox(
                      height: 420,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredPlans.length,
                        itemBuilder: (context, index) {
                          final plan = filteredPlans[index];
                          return PlanCard(
                            name: plan['name'],
                            price: (plan['price'] as num).toDouble(),
                            description: plan['description'] ?? '',
                            billingCycle: plan['billing_cycle'],
                            isSelected: _selectedPlanId == plan['id'],
                            onTap: () {
                              setState(() {
                                _selectedPlanId = plan['id'];
                              });
                            },
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Coupon Input
                  Text(
                    context.watch<LanguageProvider>().strings.haveCouponCode,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _couponController,
                          decoration: InputDecoration(
                            hintText: context.watch<LanguageProvider>().strings.enterCodeHere,
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isValidatingCoupon ? null : _handleApplyCoupon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isValidatingCoupon
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.applyBtn,
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                  if (_couponError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        _couponError!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (_appliedCoupon != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        (_appliedCoupon!['discount_percent'] as num?) != null && (_appliedCoupon!['discount_percent'] as num) > 0
                            ? l10n.discountAmount(
                                (originalPrice - payableAmount).abs().toStringAsFixed(0)
                              )
                            : l10n.freeDaysAdded((_appliedCoupon!['free_days'] as num).toInt()),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 60),

                  // Buy Now Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleBuyNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              payableAmount > 0 
                                ? '${l10n.getStartedSubscription} (৳${payableAmount.toStringAsFixed(0)})'
                                : l10n.activate,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),

            // X / Skip Button
            if (widget.isDismissible)
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool active) {
    final isMonthly = label == context.read<LanguageProvider>().strings.monthlyBilling;
    return GestureDetector(
      onTap: () => setState(() => _isMonthly = isMonthly),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class EpsWebViewScreen extends StatefulWidget {
  final String url;
  final String merchantTransactionId;

  const EpsWebViewScreen({
    super.key,
    required this.url,
    required this.merchantTransactionId,
  });

  @override
  State<EpsWebViewScreen> createState() => _EpsWebViewScreenState();
}

class _EpsWebViewScreenState extends State<EpsWebViewScreen> {
  late final WebViewController _controller;
  final _epsService = const EpsService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
          onNavigationRequest: (request) async {
            final url = request.url.toLowerCase();
            if (url.contains('status=success') ||
                url.contains('type=success')) {
              // Verify server-side
              final success = await _epsService.verifyPayment(
                widget.merchantTransactionId,
              );
              if (mounted) Navigator.of(context).pop(success);
              return NavigationDecision.prevent;
            }
            if (url.contains('status=fail') || url.contains('status=cancel')) {
              if (mounted) Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.watch<LanguageProvider>().strings.epsSafePayment),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final success = await _epsService.verifyPayment(
                widget.merchantTransactionId,
              );
              if (!context.mounted) return;
              if (success) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
