import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/pos_provider.dart';
import '../providers/admin_provider.dart';
import '../models/product.dart';
import '../services/continuous_voice_session_service.dart';
import '../utils/product_matcher.dart';
import '../utils/med_type_icons.dart';
import '../providers/language_provider.dart';
import '../utils/med_type_units.dart';
import '../widgets/taka_symbol.dart';

class ManualAddScreen extends StatefulWidget {
  final String? initialGenericFilter;

  const ManualAddScreen({super.key, this.initialGenericFilter});

  @override
  State<ManualAddScreen> createState() => _ManualAddScreenState();
}
class _ManualAddScreenState extends State<ManualAddScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late final ContinuousVoiceSessionService _voiceSession;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isListening = false;
  /// Cached in [didChangeDependencies] so [dispose] can clear search without using [context].
  POSProvider? _posProvider;
  // Track selected variant ID per product name
  final Map<String, String> _selectedVariantIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _posProvider = context.read<POSProvider>();
  }

  void _onSearchControllerChanged() {
    _posProvider?.setSearchQuery(_searchController.text);
  }

  /// Apply initial/clear search after the first frame so [POSProvider.notifyListeners]
  /// does not run during the surrounding build (e.g. when opened with a generic filter).
  void _syncInitialSearchFilter() {
    if (!mounted) return;
    if (_posProvider == null) return;
    final initialGeneric = widget.initialGenericFilter?.trim() ?? '';
    if (initialGeneric.isNotEmpty) {
      _searchController.text = initialGeneric;
    } else {
      _posProvider!.setSearchQuery('');
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInitialSearchFilter());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _voiceSession = ContinuousVoiceSessionService(
      onTranscript: (text, {required isFinal}) {
        if (!mounted) return;
        setState(() {
          _searchController.text = text;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });
      },
      onFinalTranscript: (text) async {
        if (!mounted) return;
        _handleFinalSpeechResult(context.read<POSProvider>(), text);
      },
      onError: (error) {
        if (!mounted || error.isEmpty) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().strings.voiceError(error),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
      onStateChanged: () {
        if (!mounted) return;
        final listening = _voiceSession.isListening;
        setState(() {
          _isListening = listening;
        });
        if (listening) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          _pulseController.stop();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().refreshSales();
    });
  }

  @override
  void dispose() {
    // Reset POS cart filter when leaving Manual Add so Home cart is unfiltered.
    _searchController.removeListener(_onSearchControllerChanged);
    _posProvider?.setSearchQuery('');
    _voiceSession.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    await _voiceSession.start(clearTranscript: false);
  }

  Future<void> _stopListening() async {
    await _voiceSession.stop(clearTranscript: false);
  }

  void _closeManualAdd() {
    _searchFocus.unfocus();
    Navigator.of(context).pop();
  }

  void _handleFinalSpeechResult(POSProvider posProvider, String text) {
    final products = posProvider.products;
    final best = ProductMatcher.findBestMatch(text, products);

    final l10n = context.read<LanguageProvider>().strings;
    if (best != null) {
      posProvider.updatePcQuantity(best.product, 1);
      // After successful add, clear local/global search so all medicines stay
      // visible for the next voice command.
      _searchController.clear();
      posProvider.setSearchQuery('');
      final unitLabels = MedTypeUnits.getLabels(best.product.medType, l10n);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.addedToCartDetail(best.product.name, 1, (unitLabels['unit3'] ?? 'pc').toLowerCase()),
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
            l10n.noCloseMatchFound,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _editQuantity(
    BuildContext context,
    Product product,
    String typeLabel,
    int currentQ,
  ) {
    final TextEditingController qController = TextEditingController(
      text: currentQ > 0 ? currentQ.toString() : '',
    );

    final l10n = context.read<LanguageProvider>().strings;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            l10n.setQuantityFor(typeLabel, product.name),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: qController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: AppColors.primaryDark),
            decoration: InputDecoration(
              hintText: l10n.enterAmount,
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.secondaryAccent),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: AppColors.highlightActive,
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l10n.cancelBtn,
                style: const TextStyle(color: AppColors.secondaryAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final int newQ = int.tryParse(qController.text) ?? 0;
                final provider = context.read<POSProvider>();
                
                int strips = 0;
                int pcs = 0;
                final idx = provider.cart.indexWhere((c) => c.product.id == product.id);
                if (idx >= 0) {
                  strips = provider.cart[idx].stripQuantity;
                  pcs = provider.cart[idx].pcQuantity;
                }

                if (typeLabel == 'STRIP') {
                  strips = newQ;
                } else {
                  pcs = newQ;
                }

                provider.setQuantities(product, strips, pcs);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
              ),
              child: Text(l10n.saveBtn),
            ),
          ],
        );
      },
    );
  }

  void _filterByGeneric(String generic) {
    final g = generic.trim();
    if (g.isEmpty) return;
    _searchController.text = g;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: g.length),
    );
  }

  Widget _buildManualMedTypeBadge({
    required BuildContext context,
    required POSProvider posProvider,
    required Product groupProduct,
    required Product activeProduct,
    required List<Product> variants,
    required double chipFontSize,
  }) {
    final type = activeProduct.medType ?? 'Tablet';
    final selectedPower = activeProduct.power;
    final l10n = context.read<LanguageProvider>().strings;
    final currentLabel = posProvider.getVariantLabel(activeProduct);

    return GestureDetector(
      onTap: () {
        if (variants.length <= 1) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(
              l10n.changeMedType,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: variants.length,
                itemBuilder: (c, i) {
                  final variant = variants[i];
                  final t = variant.medType ?? 'Tablet';
                  final isSelected =
                      t == type &&
                      (variant.power?.trim().toLowerCase() ?? '') ==
                          (selectedPower?.trim().toLowerCase() ?? '');
                  return ListTile(
                    leading: Icon(
                      MedTypeIcons.getIcon(t),
                      color: MedTypeIcons.getColor(t),
                      size: 20,
                    ),
                    title: Text(
                      posProvider.getVariantLabel(variant),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        MedTypeIcons.getColor(t).withValues(alpha: 0.1),
                    onTap: () {
                      setState(() {
                        _selectedVariantIds[groupProduct.name] = variant.id;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MedTypeIcons.getColor(type).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: MedTypeIcons.getColor(type).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MedTypeIcons.getIcon(type),
              size: 12,
              color: MedTypeIcons.getColor(type),
            ),
            const SizedBox(width: 4),
            Text(
              currentLabel,
              style: TextStyle(
                fontSize: chipFontSize,
                fontWeight: FontWeight.w900,
                color: MedTypeIcons.getColor(type),
              ),
            ),
            const SizedBox(width: 1),
            const Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: AppColors.secondaryAccent,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<POSProvider>();
    final adminProvider = context.watch<AdminProvider>();

    final Map<String, int> productSales = {};
    for (var sale in adminProvider.allSales) {
      productSales[sale.productName] =
          (productSales[sale.productName] ?? 0) + sale.quantity;
    }

    final List<Product> products = posProvider.groupedFilteredProducts;

    products.sort((a, b) {
      final salesA = productSales[a.name] ?? 0;
      final salesB = productSales[b.name] ?? 0;
      return salesB.compareTo(salesA);
    });

    final l10n = context.watch<LanguageProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        title: Text(
          l10n.manualAddTitle,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.white),
          onPressed: _closeManualAdd,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _closeManualAdd,
        backgroundColor: AppColors.highlightActive,
        foregroundColor: AppColors.white,
        child: const Icon(LucideIcons.check),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.secondaryAccent, width: 2),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: _isListening ? l10n.listening : l10n.searchHint,
                  hintStyle: TextStyle(
                    color: _isListening 
                      ? AppColors.highlightActive 
                      : AppColors.secondaryAccent.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                  prefixIcon: _isListening 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.highlightActive),
                          ),
                        ),
                      )
                    : const Icon(
                        LucideIcons.search,
                        color: AppColors.primaryDark,
                      ),
                  suffixIcon: _buildSuffixIcon(posProvider),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Med Type Choice Chips
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(l10n.filterAll),
                    selected: posProvider.selectedMedType == null,
                    onSelected: (selected) {
                      if (selected) posProvider.setSelectedMedType(null);
                    },
                    selectedColor: AppColors.highlightActive,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    labelStyle: TextStyle(
                      color: posProvider.selectedMedType == null
                          ? AppColors.white
                          : AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...adminProvider.medicineTypes.map((type) {
                    final isSelected = posProvider.selectedMedType == type;
                    final chipColor = MedTypeIcons.getColor(type);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        avatar: Icon(
                          MedTypeIcons.getIcon(type),
                          size: 10,
                          color: isSelected 
                            ? MedTypeIcons.getContrastColor(chipColor) 
                            : AppColors.primaryDark,
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          posProvider.setSelectedMedType(selected ? type : null);
                        },
                        selectedColor: chipColor,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? MedTypeIcons.getContrastColor(chipColor)
                              : AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Text(
                      l10n.noMatchesFound,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final product = products[idx];
                      final screenWidth = MediaQuery.sizeOf(ctx).width;
                      final isNarrow = screenWidth < 380;
                      final nameFontSize = isNarrow ? 14.0 : 17.0;
                      final chipFontSize =
                          (nameFontSize - 10).clamp(10.0, 16.0);
                      final unitPriceFontSize = isNarrow ? 15.0 : 18.0;

                      // Get currently active variant of this product name
                      final activeVariantId = _selectedVariantIds[product.name];
                      final activeProduct = activeVariantId == null
                          ? product
                          : posProvider.products.firstWhere(
                              (p) => p.id == activeVariantId,
                              orElse: () => product,
                            );

                      final l10n = context.read<LanguageProvider>().strings;
                      final unitLabels = MedTypeUnits.getLabels(activeProduct.medType, l10n);

                      final availableVariants =
                          posProvider.getAvailableVariants(product.name);

                      final cartItemIdx = posProvider.cart.indexWhere(
                        (c) => c.product.id == activeProduct.id,
                      );
                      final int stripQty = cartItemIdx >= 0
                          ? posProvider.cart[cartItemIdx].stripQuantity
                          : 0;
                      final int pcQty = cartItemIdx >= 0
                          ? posProvider.cart[cartItemIdx].pcQuantity
                          : 0;
                      final bool inCart = stripQty > 0 || pcQty > 0;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(
                            color: inCart
                                ? AppColors.highlightActive
                                : AppColors.secondaryAccent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    border: Border.all(
                                      color: AppColors.highlightActive,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    MedTypeIcons.getIcon(
                                      activeProduct.medType ?? 'Tablet',
                                    ),
                                    size: isNarrow ? 14 : 16,
                                    color: MedTypeIcons.getColor(
                                      activeProduct.medType ?? 'Tablet',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: TextStyle(
                                          fontSize: nameFontSize,
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.bold,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (product.generic.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: GestureDetector(
                                                onTap: () => _filterByGeneric(
                                                  product.generic.trim(),
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.background,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                    border: Border.all(
                                                      color: AppColors
                                                          .secondaryAccent
                                                          .withValues(
                                                              alpha: 0.5),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    product.generic.trim(),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: chipFontSize,
                                                      color: AppColors
                                                          .secondaryAccent,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (product.companyName != null &&
                                          product
                                              .companyName!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          product.companyName!.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.secondaryAccent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 7),
                                      _buildManualMedTypeBadge(
                                        context: context,
                                        posProvider: posProvider,
                                        groupProduct: product,
                                        activeProduct: activeProduct,
                                        variants: availableVariants,
                                        chipFontSize: chipFontSize,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TakaSymbol(
                                          size: isNarrow ? 13.0 : 15.0,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          activeProduct.priceStrip
                                              .toStringAsFixed(2),
                                          style: TextStyle(
                                            fontSize: unitPriceFontSize,
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      l10n.unitPrice(
                                        (unitLabels['unit2'] ?? 'STRIP')
                                            .toUpperCase(),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.secondaryAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.only(top: 9),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: AppColors.background,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (unitLabels['unit2'] != null)
                                    _ManualQuantityBox(
                                      label: unitLabels['unit2']!.toUpperCase(),
                                      quantity: stripQty,
                                      onDecrement: () => posProvider
                                          .updateStripQuantity(
                                              activeProduct, -1),
                                      onIncrement: () => posProvider
                                          .updateStripQuantity(
                                              activeProduct, 1),
                                      onTap: () => _editQuantity(
                                        context,
                                        activeProduct,
                                        unitLabels['unit2']!.toUpperCase(),
                                        stripQty,
                                      ),
                                    ),
                                  if (unitLabels['unit3'] != null)
                                    _ManualQuantityBox(
                                      label: unitLabels['unit3']!.toUpperCase(),
                                      quantity: pcQty,
                                      onDecrement: () => posProvider
                                          .updatePcQuantity(activeProduct, -1),
                                      onIncrement: () => posProvider
                                          .updatePcQuantity(activeProduct, 1),
                                      onTap: () => _editQuantity(
                                        context,
                                        activeProduct,
                                        unitLabels['unit3']!.toUpperCase(),
                                        pcQty,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSuffixIcon(POSProvider posProvider) {
    if (_isListening) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final double scale = 1.0 + (_pulseController.value * 0.2);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: IconButton(
          icon: const Icon(
            LucideIcons.micOff,
            color: AppColors.highlightActive,
            size: 18,
          ),
          onPressed: _stopListening,
        ),
      );
    }

    if (_searchController.text.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              LucideIcons.x,
              color: AppColors.secondaryAccent,
              size: 18,
            ),
            onPressed: () {
              _searchController.clear();
              _searchFocus.unfocus();
            },
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.mic,
              color: AppColors.primaryDark,
              size: 18,
            ),
            onPressed: _startListening,
          ),
        ],
      );
    }

    return IconButton(
      icon: const Icon(
        LucideIcons.mic,
        color: AppColors.primaryDark,
        size: 18,
      ),
      onPressed: _startListening,
    );
  }
}

class _ManualQuantityBox extends StatelessWidget {
  final String label;
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTap;

  const _ManualQuantityBox({
    required this.label,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 380;
    final btnW = isNarrow ? 32.0 : 36.0;
    final numW = isNarrow ? 34.0 : 40.0;
    final boxH = isNarrow ? 36.0 : 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.secondaryAccent,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: boxH,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.secondaryAccent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: quantity > 0 ? onDecrement : null,
                child: Container(
                  width: btnW,
                  alignment: Alignment.center,
                  color: quantity > 0 ? AppColors.background : Colors.grey.shade200,
                  child: Icon(
                    LucideIcons.minus,
                    size: 14,
                    color: quantity > 0 ? AppColors.primaryDark : Colors.grey.shade400,
                  ),
                ),
              ),
              InkWell(
                onTap: onTap,
                child: Container(
                  width: numW,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: AppColors.secondaryAccent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    '$quantity',
                    style: TextStyle(
                      fontSize: isNarrow ? 12.0 : 14.0,
                      color: quantity > 0 ? AppColors.primaryDark : Colors.grey.shade400,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: onIncrement,
                child: Container(
                  width: btnW,
                  alignment: Alignment.center,
                  color: AppColors.background,
                  child: const Icon(LucideIcons.plus, size: 14, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
