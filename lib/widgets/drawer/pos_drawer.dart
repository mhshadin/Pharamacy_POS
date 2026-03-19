import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/colors.dart';
import '../../services/auth_storage.dart';
import '../../screens/login_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/product_list_screen.dart';
import '../../screens/admin/returns_screen.dart';
import '../../widgets/admin_login_dialog.dart';
import 'drawer_menu_item.dart';

/// Full-featured pharmacy POS drawer.
///
/// Pass [onNavigate] from HomeScreen to wrap navigation with camera
/// stop/start logic. Standalone screens omit it for direct navigation.
///
/// When [onNavigate] is null a "Home" item is shown so users can return
/// to the root screen from any standalone screen.
class PosDrawer extends StatefulWidget {
  final Future<void> Function(Future<void> Function())? onNavigate;

  const PosDrawer({super.key, this.onNavigate});

  @override
  State<PosDrawer> createState() => _PosDrawerState();
}

class _PosDrawerState extends State<PosDrawer> {
  final _authStorage = const AuthStorage();
  AuthSession? _authSession;

  @override
  void initState() {
    super.initState();
    _loadAuthSession();
  }

  Future<void> _loadAuthSession() async {
    final session = await _authStorage.loadAuth();
    if (mounted) setState(() => _authSession = session);
  }

  /// Routes navigation through [onNavigate] when provided (HomeScreen camera
  /// handling), otherwise closes the drawer and navigates directly.
  ///
  /// [navigate] receives the live [NavigatorState] so it stays usable even
  /// after the drawer overlay is removed from the widget tree.
  Future<void> _go(Future<void> Function(NavigatorState) navigate) async {
    final nav = Navigator.of(context);
    if (widget.onNavigate != null) {
      await widget.onNavigate!(() => navigate(nav));
    } else {
      nav.pop(); // close drawer
      await navigate(nav);
    }
  }

  Future<void> _handleLogout() async {
    final nav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.primaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _authStorage.clearAuth();
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authSession?.userName ?? 'User';
    final userInitials = userName.isNotEmpty
        ? userName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return Drawer(
      backgroundColor: AppColors.primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User profile header
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryAccent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withAlpha(51),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pharmacy POS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(179),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(color: Colors.white.withAlpha(51), height: 1),

            // Menu items
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DrawerSectionLabel(title: 'NAVIGATION'),
                    DrawerMenuItem(
                      icon: LucideIcons.home,
                      label: 'Home',
                      onTap: () => _go((nav) async {
                        nav.popUntil((route) => route.isFirst);
                      }),
                    ),

                    const DrawerSectionLabel(title: 'MANAGEMENT'),
                    DrawerMenuItem(
                      icon: LucideIcons.package,
                      label: 'Product List',
                      onTap: () => _go((nav) async {
                        await nav.push(MaterialPageRoute(
                          builder: (_) =>
                              const ProductListScreen(isAdmin: false),
                        ));
                      }),
                    ),
                    DrawerMenuItem(
                      icon: LucideIcons.rotateCcw,
                      label: 'Returns',
                      onTap: () => _go((nav) async {
                        await nav.push(MaterialPageRoute(
                          builder: (_) =>
                              const ReturnsScreen(isStandalone: true),
                        ));
                      }),
                    ),

                    const DrawerSectionLabel(title: 'INVENTORY'),
                    DrawerMenuItem(
                      icon: LucideIcons.alertTriangle,
                      label: 'Low Stock',
                      onTap: () => _go((nav) async {
                        await nav.push(MaterialPageRoute(
                          builder: (_) => const LowStockStandaloneScreen(),
                        ));
                      }),
                    ),
                    DrawerMenuItem(
                      icon: LucideIcons.clock,
                      label: 'Expiring Soon',
                      onTap: () => _go((nav) async {
                        await nav.push(MaterialPageRoute(
                          builder: (_) =>
                              const ExpiringSoonStandaloneScreen(),
                        ));
                      }),
                    ),

                    const DrawerSectionLabel(title: 'REPORTS'),
                    DrawerMenuItem(
                      icon: LucideIcons.lineChart,
                      label: 'Sales Report',
                      onTap: () => _go((nav) async {
                        await nav.push(MaterialPageRoute(
                          builder: (_) =>
                              const SalesReportStandaloneScreen(),
                        ));
                      }),
                    ),

                    const DrawerSectionLabel(),
                    DrawerMenuItem(
                      icon: LucideIcons.shieldCheck,
                      label: 'Admin Panel',
                      onTap: () => _go((nav) async {
                        final result = await showDialog<bool>(
                          context: nav.overlay!.context,
                          barrierDismissible: false,
                          builder: (_) => const AdminLoginDialog(),
                        );
                        if (result == true) {
                          await nav.push(MaterialPageRoute(
                            builder: (_) => const AdminDashboardScreen(),
                          ));
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Logout button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(LucideIcons.logOut, size: 18),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withAlpha(128)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
