import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import '../../utils/colors.dart';
import '../../utils/inventory_alert_tiers.dart';
import 'low_stock_screen.dart';
import 'expiring_soon_screen.dart';
import '../../providers/language_provider.dart';
import '../../models/product.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _productTitle(Product product) {
    final type = product.medType?.trim();
    final power = product.power?.trim();
    if (power != null && power.isNotEmpty) {
      if (type != null && type.isNotEmpty) {
        return '${product.name} (${type} • ${power})';
      }
      return '${product.name} (${power})';
    }
    if (type != null && type.isNotEmpty) {
      return '${product.name} (${type})';
    }
    return product.name;
  }

  @override
  void initState() {
    super.initState();
    // Mark notifications as read when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().markNotificationsAsRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.notificationsTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          final lowStock = adminProvider.lowStockProducts;
          final expiringSoon = adminProvider.expiringSoonProducts;

          if (lowStock.isEmpty && expiringSoon.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 100,
                    color: Colors.grey.withAlpha(128),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.noNotifications,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            children: [
              if (lowStock.isNotEmpty) ...[
                _buildSectionHeader(
                  l10n.lowStockTitle,
                  Icons.warning_amber_rounded,
                  AppColors.primaryDark,
                ),
                ...lowStock.map((product) => _buildNotificationItem(
                  context: context,
                  title: _productTitle(product),
                  subtitle: l10n.lowStockSubtitle(product.stockStrips),
                  icon: Icons.inventory_2_outlined,
                  color: adminProvider.lowStockTierFor(product).accentColor,
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LowStockScreen()),
                    (route) => route.isFirst,
                  ),
                )),
              ],
              if (expiringSoon.isNotEmpty) ...[
                if (lowStock.isNotEmpty) const SizedBox(height: 20),
                _buildSectionHeader(
                  l10n.expiringSoonTitle,
                  Icons.timer_outlined,
                  AppColors.primaryDark,
                ),
                ...expiringSoon.map((product) {
                  final tier = adminProvider.expiryTierFor(product);
                  final iconData = switch (tier) {
                    InventoryAlertTier.critical => Icons.error_outline,
                    InventoryAlertTier.moderate => Icons.timer_outlined,
                    InventoryAlertTier.mild => Icons.calendar_today_outlined,
                  };
                  return _buildNotificationItem(
                    context: context,
                    title: _productTitle(product),
                    subtitle: l10n.expiresOnDate(
                      product.expiryDate?.toLocal().toString().split(' ')[0] ??
                          '',
                    ),
                    icon: iconData,
                    color: tier.accentColor,
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExpiringSoonScreen(),
                      ),
                      (route) => route.isFirst,
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(50)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
