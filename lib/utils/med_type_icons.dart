import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MedTypeIcons {
  static IconData getIcon(String? type) {
    if (type == null) return LucideIcons.pill;
    
    switch (type.toLowerCase()) {
      case 'tablet':
      case 'pill':
        return LucideIcons.pill;
      case 'capsule':
        return LucideIcons.pill;
      case 'syrup':
      case 'liquid':
      case 'suspension':
        return LucideIcons.droplets;
      case 'injection':
      case 'injectable':
      case 'vial':
      case 'ampoule':
        return LucideIcons.syringe;
      case 'cream':
      case 'ointment':
      case 'gel':
        return LucideIcons.hand;
      case 'drops':
      case 'eye drops':
      case 'ear drops':
        return LucideIcons.droplet;
      case 'inhaler':
      case 'spray':
        return LucideIcons.wind;
      case 'patch':
        return LucideIcons.stickyNote;
      case 'powder':
      case 'sachet':
        return LucideIcons.layers;
      case 'suppository':
        return LucideIcons.arrowDown;
      default:
        return LucideIcons.pill;
    }
  }

  static Color getColor(String? type) {
    if (type == null) return const Color(0xFF64748B); // slate
    
    switch (type.toLowerCase()) {
      case 'tablet':
        return const Color(0xFF0EA5E9); // sky
      case 'capsule':
        return const Color(0xFF8B5CF6); // violet
      case 'syrup':
      case 'suspension':
        return const Color(0xFFF97316); // orange
      case 'injection':
        return const Color(0xFFEF4444); // red
      case 'cream':
      case 'ointment':
      case 'gel':
        return const Color(0xFF10B981); // emerald
      case 'drops':
        return const Color(0xFF06B6D4); // cyan
      case 'inhaler':
        return const Color(0xFF6366F1); // indigo
      default:
        return const Color(0xFF64748B);
    }
  }

  static Color getContrastColor(Color background) {
    // Standard relative luminance formula
    double luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
