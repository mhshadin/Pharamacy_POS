import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import 'low_stock_screen.dart';
import 'expiring_soon_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
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
                    'No new notifications',
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
                _buildSectionHeader('Low Stock Alerts', Icons.warning_amber_rounded, Colors.orange),
                ...lowStock.map((product) => _buildNotificationItem(
                  context: context,
                  title: product.name,
                  subtitle: 'Item is low on stock (${product.stockStrips} strips left)',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LowStockScreen()),
                  ),
                )),
              ],
              if (expiringSoon.isNotEmpty) ...[
                if (lowStock.isNotEmpty) const SizedBox(height: 20),
                _buildSectionHeader('Expiring Soon', Icons.timer_outlined, Colors.red),
                ...expiringSoon.map((product) => _buildNotificationItem(
                  context: context,
                  title: product.name,
                  subtitle: 'Expires on ${product.expiryDate?.toLocal().toString().split(' ')[0]}',
                  icon: Icons.event_busy_outlined,
                  color: Colors.red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExpiringSoonScreen()),
                  ),
                )),
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
