import 'package:flutter/material.dart';
import '../models/product.dart';
import 'colors.dart';

/// Green / amber / red severity for inventory alerts (low stock & expiry).
enum InventoryAlertTier {
  /// Closest to OK (green).
  mild,

  /// Middle urgency (amber).
  moderate,

  /// Worst case (red).
  critical,
}

extension InventoryAlertTierColors on InventoryAlertTier {
  Color get accentColor => switch (this) {
        InventoryAlertTier.critical => AppColors.error,
        InventoryAlertTier.moderate => AppColors.warningOrange,
        InventoryAlertTier.mild => AppColors.success,
      };
}

/// Ratio of current strips to minimum; only valid when [Product.minStockLevel] > 0.
InventoryAlertTier computeLowStockTier(Product p) {
  if (p.minStockLevel <= 0) return InventoryAlertTier.critical;
  if (p.stockStrips == 0) return InventoryAlertTier.critical;
  final r = p.stockStrips / p.minStockLevel;
  if (r < 1 / 3) return InventoryAlertTier.critical;
  if (r < 2 / 3) return InventoryAlertTier.moderate;
  return InventoryAlertTier.mild;
}

/// Uses day thresholds from settings. For products outside the expiring-soon window,
/// returns [InventoryAlertTier.mild].
InventoryAlertTier computeExpiryTier({
  required int daysUntilExpiry,
  required int criticalExpiryDays,
  required int moderateExpiryDays,
  required int expiringSoonDays,
}) {
  if (daysUntilExpiry < 0) return InventoryAlertTier.critical;
  if (daysUntilExpiry > expiringSoonDays) return InventoryAlertTier.mild;
  if (daysUntilExpiry <= criticalExpiryDays) return InventoryAlertTier.critical;
  if (daysUntilExpiry <= moderateExpiryDays) return InventoryAlertTier.moderate;
  return InventoryAlertTier.mild;
}

/// Urgency for subscription renewal (dashboard card); uses same accent colors as low stock.
InventoryAlertTier subscriptionRenewalTier(int daysRemaining) {
  if (daysRemaining < 0) return InventoryAlertTier.critical;
  if (daysRemaining <= 7) return InventoryAlertTier.critical;
  if (daysRemaining <= 30) return InventoryAlertTier.moderate;
  return InventoryAlertTier.mild;
}
