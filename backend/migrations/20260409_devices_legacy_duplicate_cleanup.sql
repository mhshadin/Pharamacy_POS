-- Cleanup legacy duplicate device rows created by timestamp-based hardware UIDs.
-- Safe to run multiple times.

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_device_keepers AS
SELECT
  d.pharmacy_id,
  COALESCE(NULLIF(TRIM(d.device_model), ''), '__unknown_model__') AS model_key,
  COALESCE(NULLIF(TRIM(d.device_display_name), ''), '__unknown_name__') AS name_key,
  SUBSTRING_INDEX(
    GROUP_CONCAT(d.id ORDER BY COALESCE(d.last_login_at, '1970-01-01 00:00:00') DESC, d.id DESC),
    ',',
    1
  ) AS keep_id,
  MAX(CASE WHEN d.is_active_seller = 1 THEN 1 ELSE 0 END) AS had_active
FROM devices d
WHERE d.hardware_uid LIKE 'device_%'
GROUP BY
  d.pharmacy_id,
  COALESCE(NULLIF(TRIM(d.device_model), ''), '__unknown_model__'),
  COALESCE(NULLIF(TRIM(d.device_display_name), ''), '__unknown_name__')
HAVING COUNT(*) > 1;

-- If any duplicate group had an active seller, keep active flag on the survivor.
UPDATE devices d
JOIN tmp_device_keepers k ON d.id = k.keep_id
SET d.is_active_seller = IF(k.had_active = 1, 1, d.is_active_seller),
    d.activated_at = IF(k.had_active = 1, COALESCE(d.activated_at, NOW()), d.activated_at);

-- Delete redundant legacy rows in each duplicate group.
DELETE d
FROM devices d
JOIN tmp_device_keepers k
  ON d.pharmacy_id = k.pharmacy_id
  AND COALESCE(NULLIF(TRIM(d.device_model), ''), '__unknown_model__') = k.model_key
  AND COALESCE(NULLIF(TRIM(d.device_display_name), ''), '__unknown_name__') = k.name_key
WHERE d.id <> k.keep_id
  AND d.hardware_uid LIKE 'device_%';

DROP TEMPORARY TABLE IF EXISTS tmp_device_keepers;
