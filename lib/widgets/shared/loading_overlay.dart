import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pharmacy_pos/utils/colors.dart';

class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isGlass;

  const LoadingOverlay({
    super.key,
    this.message,
    this.isGlass = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );

    if (isGlass) {
      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: AppColors.primaryDark.withValues(alpha: 0.3),
            ),
          ),
          content,
        ],
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: content,
    );
  }
}
