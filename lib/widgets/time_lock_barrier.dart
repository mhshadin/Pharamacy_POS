import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/time_service.dart';
import '../utils/colors.dart';

class TimeLockBarrier extends StatefulWidget {
  final Widget child;
  const TimeLockBarrier({super.key, required this.child});

  @override
  State<TimeLockBarrier> createState() => _TimeLockBarrierState();
}

class _TimeLockBarrierState extends State<TimeLockBarrier> {
  bool _isLocked = false;
  String _message = '';
  bool _isChecking = false;
  final TimeService _timeService = TimeService();

  @override
  void initState() {
    super.initState();
    _performFullTimeCheck();
  }

  Future<void> _performFullTimeCheck() async {
    setState(() => _isChecking = true);

    // 1. Check for tampering (offline check)
    final isTampered = await _timeService.isTimeTampered();
    if (isTampered) {
      _lock('Clock tampering detected! Your phone time was moved backward. Please connect to the internet to verify your time.');
      return;
    }

    // 2. Check for drift (online check)
    final serverTime = await _timeService.fetchServerTime();
    if (serverTime != null) {
      if (_timeService.isTimeDrifted(serverTime)) {
        _lock('Time Mismatch! Your phone clock differs from the server by more than 5 minutes. Please set your clock to "Automatic".');
        return;
      }
    }

    // 3. All good
    _unlock();
  }

  void _lock(String msg) {
    if (mounted) {
      setState(() {
        _isLocked = true;
        _message = msg;
        _isChecking = false;
      });
    }
  }

  void _unlock() {
    if (mounted) {
      setState(() {
        _isLocked = false;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked) 
          PopScope(
            canPop: false, // Disable back button
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // Full screen blur
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: AppColors.primaryDark.withAlpha(180)),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.white.withAlpha(50), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.clock, color: AppColors.error, size: 48),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Access Blocked',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _message,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.white.withAlpha(200),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isChecking ? null : _performFullTimeCheck,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.white,
                                  foregroundColor: AppColors.primaryDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isChecking 
                                  ? const SizedBox(
                                      width: 24, 
                                      height: 24, 
                                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryDark)
                                    )
                                  : const Text(
                                      'Check Again', 
                                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
