-- Migration v3: Add missing columns to the `devices` table
-- Run this once on your live database to fix registration failures.

ALTER TABLE `devices`
  ADD COLUMN IF NOT EXISTS `device_model`        VARCHAR(255)  DEFAULT NULL      AFTER `device_name`,
  ADD COLUMN IF NOT EXISTS `device_display_name` VARCHAR(255)  DEFAULT NULL      AFTER `device_model`,
  ADD COLUMN IF NOT EXISTS `is_active_seller`    TINYINT(1)    NOT NULL DEFAULT 1 AFTER `is_authorized`,
  ADD COLUMN IF NOT EXISTS `activated_at`        DATETIME      DEFAULT NULL      AFTER `is_active_seller`;

-- Verify the result
DESCRIBE `devices`;
