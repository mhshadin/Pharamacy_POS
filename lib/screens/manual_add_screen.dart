import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/pos_provider.dart';
import '../providers/admin_provider.dart';
import '../models/product.dart';
import '../services/speech_service.dart';
import '../utils/product_matcher.dart';

class ManualAddScreen extends StatefulWidget {
  const ManualAddScreen({super.key});

  @override
  State<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends State<ManualAddScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().refreshSales();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _startListening(POSProvider posProvider) async {
    setState(() {
      _isListening = true;
    });

    final service = SpeechService.instance;

    await service.startListening(
      preferredLocaleId: 'en_US',
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _searchController.text = text;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });

        if (isFinal) {
          _handleFinalSpeechResult(posProvider, text);
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
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

  Future<void> _stopListening() async {
    await SpeechService.instance.stopListening();
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
  }

  void _handleFinalSpeechResult(POSProvider posProvider, String text) {
    final products = posProvider.products;
    final best = ProductMatcher.findBestMatch(text, products);

    if (best != null) {
      // Auto add 1 PC for the best matched product.
      posProvider.updatePcQuantity(best.product, 1);
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
      // No confident match; keep text for manual correction and suggestions.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No close match found. Please edit the name.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Handle manual quantity input via Dialog
  void _editQuantity(
    BuildContext context,
    Product product,
    String typeLabel, // 'STRIP' or 'PC'
    int currentQ,
  ) {
    final TextEditingController qController = TextEditingController(
      text: currentQ > 0 ? currentQ.toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            'Set $typeLabel Quantity: \n${product.name}',
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
            decoration: const InputDecoration(
              hintText: 'Enter amount...',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.secondaryAccent),
              ),
              focusedBorder: UnderlineInputBorder(
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final int newQ = int.tryParse(qController.text) ?? 0;
                final provider = context.read<POSProvider>();
                
                // Get existing item or defaults
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<POSProvider>();
    final adminProvider = context.watch<AdminProvider>();

    // Compute total sales per product name for sorting
    final Map<String, int> productSales = {};
    for (var sale in adminProvider.allSales) {
      productSales[sale.productName] =
          (productSales[sale.productName] ?? 0) + sale.quantity;
    }

    // Filter and Sort Products
    List<Product> products = posProvider.products.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.generic.toLowerCase().contains(_searchQuery);
    }).toList();

    products.sort((a, b) {
      final salesA = productSales[a.name] ?? 0;
      final salesB = productSales[b.name] ?? 0;
      return salesB.compareTo(salesA); // Descending (most sold first)
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        title: const Text(
          'MANUAL ADD',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
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
                  hintText: 'Search product or generic name...',
                  hintStyle: TextStyle(
                    color: AppColors.secondaryAccent.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
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

          // Product List
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'No products found matching search.',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final product = products[idx];

                      // Check if in cart to sync quantity
                      final cartItemIdx = posProvider.cart.indexWhere(
                        (c) => c.product.id == product.id,
                      );
                      final int stripQty = cartItemIdx >= 0
                          ? posProvider.cart[cartItemIdx].stripQuantity
                          : 0;
                      final int pcQty = cartItemIdx >= 0
                          ? posProvider.cart[cartItemIdx].pcQuantity
                          : 0;
                      final bool inCart = stripQty > 0 || pcQty > 0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(
                            color: inCart
                                ? AppColors.highlightActive
                                : AppColors.secondaryAccent,
                            width: inCart ? 3 : 2,
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
                            // Product Info
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    border: Border.all(
                                      color: AppColors.highlightActive,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                    child: const Icon(
                                      LucideIcons.package,
                                      color: AppColors.primaryDark,
                                    ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.bold,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product.generic,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondaryAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('৳', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                                        Text(
                                          product.priceStrip.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      'STRIP PRICE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.secondaryAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Controls Row
                            Container(
                              padding: const EdgeInsets.only(top: 8),
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
                                  // STRIP Controls
                                  _ManualQuantityBox(
                                    label: 'STRIP',
                                    quantity: stripQty,
                                    onDecrement: () => posProvider.updateStripQuantity(product, -1),
                                    onIncrement: () => posProvider.updateStripQuantity(product, 1),
                                    onTap: () => _editQuantity(context, product, 'STRIP', stripQty),
                                  ),
                                  // PC Controls
                                  _ManualQuantityBox(
                                    label: 'PC',
                                    quantity: pcQty,
                                    onDecrement: () => posProvider.updatePcQuantity(product, -1),
                                    onIncrement: () => posProvider.updatePcQuantity(product, 1),
                                    onTap: () => _editQuantity(context, product, 'PC', pcQty),
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
      return IconButton(
        icon: const Icon(
          LucideIcons.micOff,
          color: AppColors.highlightActive,
          size: 18,
        ),
        onPressed: _stopListening,
      );
    }

    if (_searchController.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(
          LucideIcons.x,
          color: AppColors.secondaryAccent,
          size: 18,
        ),
        onPressed: () {
          _searchController.clear();
          _searchFocus.unfocus();
        },
      );
    }

    return IconButton(
      icon: const Icon(
        LucideIcons.mic,
        color: AppColors.primaryDark,
        size: 18,
      ),
      onPressed: () => _startListening(posProvider),
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
          height: 36,
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
                  width: 32,
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
                  width: 36,
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
                      fontSize: 14,
                      color: quantity > 0 ? AppColors.primaryDark : Colors.grey.shade400,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: onIncrement,
                child: Container(
                  width: 32,
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
