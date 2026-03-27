import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';
import '../../services/auth_storage.dart';
import '../../providers/admin_provider.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh session when returning from profile edits so name/avatar update immediately.
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
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    final avatarUrl = _authSession?.userAvatarUrl;

    // Check if google user for badge
    final isGoogleUser = _authSession?.googleAccessToken != null;

    final admin = context.watch<AdminProvider>();
    final isSyncing = admin.isSyncing;
    final lastSync = admin.lastSyncTime;
    final syncError = admin.syncError;
    
    String syncText = 'Drive Backup: Not synced';
    Color syncColor = Colors.white.withAlpha(150);
    IconData syncIcon = LucideIcons.cloudOff;
    
    if (isSyncing) {
      syncText = 'Drive Backup: Syncing...';
      syncColor = AppColors.primaryDark.withValues(alpha: 0.5);
      syncIcon = LucideIcons.loader;
    } else if (syncError != null) {
      syncText = 'Drive Backup: Failed';
      syncColor = Colors.red.shade300;
      syncIcon = LucideIcons.alertTriangle;
    } else if (lastSync != null) {
      syncText = 'Synced: ${DateFormat('MMM dd, HH:mm').format(lastSync)}';
      syncColor = AppColors.success;
      syncIcon = LucideIcons.checkCircle2;
    }

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
                    Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.secondaryAccent, AppColors.secondaryAccent.withAlpha(150)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.1),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        userInitials,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      userInitials,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (isGoogleUser)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_G_logo.svg',
                                width: 14,
                                height: 14,
                                errorBuilder: (context, error, stackTrace) => 
                                  const Icon(LucideIcons.chrome, size: 12, color: Color(0xFF4285F4)),
                              ),
                            ),
                          ),
                      ],
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
                      _authSession?.userRole.toUpperCase() ?? 'PHARMACY POS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withAlpha(180),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(syncIcon, color: syncColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          syncText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: syncColor,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
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
                        await nav.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProductListScreen(isAdmin: false),
                          ),
                          (route) => route.isFirst,
                        );
                      }),
                    ),
                    DrawerMenuItem(
                      icon: LucideIcons.rotateCcw,
                      label: 'Returns',
                      onTap: () => _go((nav) async {
                        await nav.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ReturnsScreen(isStandalone: true),
                          ),
                          (route) => route.isFirst,
                        );
                      }),
                    ),

                    const DrawerSectionLabel(title: 'INVENTORY'),
                    DrawerMenuItem(
                      icon: LucideIcons.alertTriangle,
                      label: 'Low Stock',
                      onTap: () => _go((nav) async {
                        await nav.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LowStockStandaloneScreen(),
                          ),
                          (route) => route.isFirst,
                        );
                      }),
                    ),
                    DrawerMenuItem(
                      icon: LucideIcons.clock,
                      label: 'Expiring Soon',
                      onTap: () => _go((nav) async {
                        await nav.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ExpiringSoonStandaloneScreen(),
                          ),
                          (route) => route.isFirst,
                        );
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
                          await nav.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const AdminDashboardScreen(),
                            ),
                            (route) => route.isFirst,
                          );
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
