import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/admin_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePin() async {
    if (!_formKey.currentState!.validate()) return;

    final admin = context.read<AdminProvider>();
    final success = await admin.updatePin(
      _oldPinCtrl.text.trim(),
      _newPinCtrl.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      _oldPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect current PIN.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 24),
                  child: Text(
                    'Admin Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                _buildSection(
                  title: 'Security',
                  icon: LucideIcons.shieldCheck,
                  child: Column(
                    children: [
                      _buildPinField(
                        controller: _oldPinCtrl,
                        label: 'Current Admin PIN',
                        obscure: _obscureOld,
                        onToggle: () =>
                            setState(() => _obscureOld = !_obscureOld),
                      ),
                      const SizedBox(height: 16),
                      _buildPinField(
                        controller: _newPinCtrl,
                        label: 'New Admin PIN',
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 16),
                      _buildPinField(
                        controller: _confirmPinCtrl,
                        label: 'Confirm New PIN',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != _newPinCtrl.text) return 'PINs do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _updatePin,
                          icon: const Icon(
                            LucideIcons.save,
                            color: AppColors.white,
                          ),
                          label: const Text(
                            'Update PIN',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(LucideIcons.key, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator:
          validator ??
          (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v.length < 4) return 'Too short (min 4 digits)';
            return null;
          },
    );
  }
}
