-- Add `renewed_at` to track subscription creation/renewal time.
-- Target: MariaDB 10.5+ / MySQL 8+. Run once on live DB.

ALTER TABLE `subscribers`
  ADD COLUMN IF NOT EXISTS `renewed_at` DATETIME NULL DEFAULT NULL AFTER `valid_until`;
