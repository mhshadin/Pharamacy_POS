import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/colors.dart';
import '../providers/admin_provider.dart';
import 'package:provider/provider.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorText;
  bool _obscure = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = 'Please enter the PIN');
      return;
    }
    final admin = context.read<AdminProvider>();
    if (admin.login(pin)) {
      Navigator.pop(context, true);
    } else {
      setState(() => _errorText = 'Wrong PIN. Try again.');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.secondaryAccent, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.lock,
                size: 40,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Admin Login',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter admin PIN to continue',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // PIN field
            TextField(
              controller: _pinController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '• • • • •',
                hintStyle: TextStyle(
                  color: AppColors.secondaryAccent.withValues(alpha: 0.5),
                  letterSpacing: 8,
                ),
                errorText: _errorText,
                errorStyle: const TextStyle(fontWeight: FontWeight.bold),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryAccent,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryAccent,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryDark,
                    width: 3,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: AppColors.secondaryAccent,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primaryDark,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
