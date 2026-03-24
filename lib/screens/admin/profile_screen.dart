import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/admin_provider.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../subscription_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKeyPin = GlobalKey<FormState>();
  final _formKeyPass = GlobalKey<FormState>();
  
  final _oldPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscurePass = true;
  bool _obscurePassConfirm = true;

  bool _pinExpanded = false;
  bool _passExpanded = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePin() async {
    if (!_formKeyPin.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final admin = context.read<AdminProvider>();
    final success = await admin.updatePin(
      _oldPinCtrl.text.trim(),
      _newPinCtrl.text.trim(),
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      _oldPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
      setState(() => _pinExpanded = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect current PIN.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKeyPass.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final admin = context.read<AdminProvider>();
    final token = admin.authSession?.licenseToken;
    
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await const AuthService().setPassword(
        token: token,
        newPassword: _newPassCtrl.text,
      );
      
      if (!mounted) return;
      
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      setState(() {
        _passExpanded = false;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password set successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('AuthException: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final session = admin.authSession;
    final isGoogleUser = session?.googleAccessToken != null;
    
    final userName = session?.userName ?? 'Admin';
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : 'A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // 1. HERO SECTION
              _buildHero(userName, userInitials, session?.userRole, session?.subscriptionStatus),
              const SizedBox(height: 24),
              
              // 2. ACCOUNT INFO
              _buildInfoCard(session),
              const SizedBox(height: 16),

              // 2.5 SUBSCRIPTION SECTION
              _buildSubscriptionCard(session),
              const SizedBox(height: 16),
              
              // 3. SECURITY SECTION
              _buildSecuritySection(isGoogleUser),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(String name, String initials, String? role, String? subStatus) {
    final isSubActive = subStatus?.toLowerCase() == 'active';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, Color(0xFF1A2138)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white.withAlpha(30),
              border: Border.all(color: AppColors.white.withAlpha(50), width: 4),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                role?.toUpperCase() ?? 'ADMIN', 
                AppColors.secondaryAccent.withAlpha(50), 
                AppColors.secondaryAccent
              ),
              const SizedBox(width: 8),
              _buildBadge(
                subStatus?.toUpperCase() ?? 'TRIAL', 
                isSubActive ? AppColors.success.withAlpha(50) : AppColors.error.withAlpha(50), 
                isSubActive ? AppColors.success : AppColors.error
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textCol.withAlpha(80)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoCard(dynamic session) {
    return _Card(
      title: 'Account Information',
      icon: LucideIcons.user,
      child: Column(
        children: [
          _buildInfoRow(LucideIcons.mail, 'Email Address', session?.userEmail ?? 'Not provided'),
          const Divider(height: 24),
          _buildInfoRow(LucideIcons.hash, 'User ID', session?.userId ?? 'N/A'),
          const Divider(height: 24),
          _buildInfoRow(LucideIcons.calendar, 'Subscription Valid Until', 
            session?.subscriptionValidUntil != null && session!.subscriptionValidUntil.isNotEmpty
            ? session.subscriptionValidUntil.split(' ')[0]
            : 'N/A'
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(AuthSession? session) {
    if (session == null) return const SizedBox.shrink();
    
    final isSubActive = session.subscriptionStatus.toLowerCase() == 'active';
    final planName = session.planName;
    
    return _Card(
      title: 'Subscription Management',
      icon: LucideIcons.creditCard,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isSubActive ? AppColors.success : AppColors.error).withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSubActive ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                  color: isSubActive ? AppColors.success : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      isSubActive ? 'Active Subscription' : 'Expired / Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSubActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(
                        pharmacyId: session.userId,
                        isDismissible: true,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  isSubActive ? 'Renew' : 'Activate',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (session.subscriptionValidUntil.isNotEmpty) ...[
            const Divider(height: 32),
            _buildInfoRow(
              LucideIcons.calendarClock, 
              'Renewal Date', 
              session.subscriptionValidUntil.split(' ')[0]
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryAccent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(bool isGoogleUser) {
    return Column(
      children: [
        // PIN Form (Always present, but collapsible)
        _buildCollapsibleSection(
          title: 'Update Admin PIN',
          icon: LucideIcons.shieldCheck,
          isExpanded: _pinExpanded,
          onToggle: () => setState(() => _pinExpanded = !_pinExpanded),
          child: Form(
            key: _formKeyPin,
            child: Column(
              children: [
                _buildField(
                  controller: _oldPinCtrl,
                  label: 'Current PIN',
                  icon: LucideIcons.key,
                  obscure: _obscureOld,
                  isPin: true,
                  onToggle: () => setState(() => _obscureOld = !_obscureOld),
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _newPinCtrl,
                  label: 'New PIN',
                  icon: LucideIcons.lock,
                  obscure: _obscureNew,
                  isPin: true,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _confirmPinCtrl,
                  label: 'Confirm PIN',
                  icon: LucideIcons.checkCircle,
                  obscure: _obscureConfirm,
                  isPin: true,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _newPinCtrl.text) return 'PINs do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildSubmitButton('Update Security PIN', _updatePin),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),

        // Password Form (Only for Google users to set password)
        if (isGoogleUser) ...[
          _buildGoogleBadge(),
          const SizedBox(height: 16),
          _buildCollapsibleSection(
            title: 'Set Local Password',
            subtitle: 'Create a password to also log in via email',
            icon: LucideIcons.lock,
            isExpanded: _passExpanded,
            onToggle: () => setState(() => _passExpanded = !_passExpanded),
            child: Form(
              key: _formKeyPass,
              child: Column(
                children: [
                  _buildField(
                    controller: _newPassCtrl,
                    label: 'New Password',
                    icon: LucideIcons.lock,
                    obscure: _obscurePass,
                    onToggle: () => setState(() => _obscurePass = !_obscurePass),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 8) return 'Min 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _confirmPassCtrl,
                    label: 'Confirm Password',
                    icon: LucideIcons.checkCircle,
                    obscure: _obscurePassConfirm,
                    onToggle: () => setState(() => _obscurePassConfirm = !_obscurePassConfirm),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != _newPassCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSubmitButton('Secure Local Account', _updatePassword),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGoogleBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4).withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4285F4).withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(LucideIcons.chrome, color: Color(0xFF4285F4), size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Managed Account',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4285F4), fontSize: 13),
                ),
                Text(
                  'You log in using your Google identity',
                  style: TextStyle(color: Color(0xFF4285F4), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primaryDark, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                        ),
                        if (subtitle != null)
                          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.secondaryAccent)),
                      ],
                    ),
                  ),
                  Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, 
                    color: AppColors.secondaryAccent, size: 20),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(20), child: child),
          ],
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    bool isPin = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isPin ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        fontWeight: FontWeight.bold, 
        letterSpacing: isPin ? 4 : 0,
        color: AppColors.primaryDark
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.primaryDark.withAlpha(5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
      validator: validator ?? (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (isPin && v.length < 4) return 'Min 4 digits';
        return null;
      },
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
