import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';

class SubscriptionWarningDialog extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback onRenew;
  final VoidCallback onDismiss;

  const SubscriptionWarningDialog({
    super.key,
    required this.daysRemaining,
    required this.onRenew,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Determine color and icon based on urgency
    Color mainColor;
    IconData icon;
    String title;
    
    if (daysRemaining <= 1) {
      mainColor = AppColors.error;
      icon = LucideIcons.alertTriangle;
      title = 'Last Day!';
    } else if (daysRemaining <= 5) {
      mainColor = Colors.orange;
      icon = LucideIcons.alertCircle;
      title = 'Action Required';
    } else {
      mainColor = AppColors.primaryDark;
      icon = LucideIcons.info;
      title = 'Subscription Note';
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with color bar
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: mainColor.withAlpha(30),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mainColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: mainColor.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Your current plan will end in '),
                          TextSpan(
                            text: '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}',
                            style: TextStyle(
                              color: mainColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: '. Renew now to prevent any service interruption.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Later',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: onRenew,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Renew Now',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
