-- Multi-device active seller: extend `devices` + backfill one active device per pharmacy.
-- Target: MariaDB 10.5+ / MySQL 8+. Run once.

ALTER TABLE `devices`
  ADD COLUMN IF NOT EXISTS `device_model` VARCHAR(255) NULL DEFAULT NULL AFTER `device_name`,
  ADD COLUMN IF NOT EXISTS `device_display_name` VARCHAR(255) NULL DEFAULT NULL AFTER `device_model`,
  ADD COLUMN IF NOT EXISTS `is_active_seller` TINYINT(1) NOT NULL DEFAULT 0 AFTER `last_login_at`,
  ADD COLUMN IF NOT EXISTS `activated_at` DATETIME NULL DEFAULT NULL AFTER `is_active_seller`,
  ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `activated_at`;

UPDATE `devices`
SET `device_display_name` = COALESCE(NULLIF(TRIM(`device_display_name`), ''), NULLIF(TRIM(`device_name`), ''), 'POS Device')
WHERE `device_display_name` IS NULL OR TRIM(`device_display_name`) = '';

-- Pick one device per pharmacy with no active seller: earliest last_login (tie-break by id).
UPDATE `devices` d
INNER JOIN (
  SELECT d1.`pharmacy_id`, MIN(d1.`id`) AS `chosen_id`
  FROM `devices` d1
  INNER JOIN (
    SELECT d2.`pharmacy_id`, MIN(COALESCE(d2.`last_login_at`, '1970-01-01 00:00:00')) AS `ml`
    FROM `devices` d2
    GROUP BY d2.`pharmacy_id`
  ) t ON d1.`pharmacy_id` = t.`pharmacy_id`
     AND COALESCE(d1.`last_login_at`, '1970-01-01 00:00:00') = t.`ml`
  GROUP BY d1.`pharmacy_id`
) pick ON d.`pharmacy_id` = pick.`pharmacy_id` AND d.`id` = pick.`chosen_id`
SET d.`is_active_seller` = 1,
    d.`activated_at` = COALESCE(d.`activated_at`, d.`last_login_at`, NOW())
WHERE NOT EXISTS (
  SELECT 1 FROM `devices` x
  WHERE x.`pharmacy_id` = d.`pharmacy_id` AND x.`is_active_seller` = 1
);

-- If multiple rows still marked active, keep smallest `id` only.
UPDATE `devices` d
INNER JOIN (
  SELECT `pharmacy_id`, MIN(`id`) AS `keep_id`
  FROM `devices`
  WHERE `is_active_seller` = 1
  GROUP BY `pharmacy_id`
) k ON d.`pharmacy_id` = k.`pharmacy_id`
SET d.`is_active_seller` = IF(d.`id` = k.`keep_id`, 1, 0);

CREATE INDEX IF NOT EXISTS `idx_devices_pharmacy_active_seller` ON `devices` (`pharmacy_id`, `is_active_seller`);
