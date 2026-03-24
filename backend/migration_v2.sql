-- Robust Migration Script: Subscription System v1 to v2
-- Purpose: Safely update schema even if partially applied.

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;

-- 1. Create subscription_plans if it doesn't exist
CREATE TABLE IF NOT EXISTS `subscription_plans` (
  `id` varchar(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `description` text DEFAULT NULL,
  `billing_cycle` enum('monthly','yearly','lifetime') NOT NULL,
  `trial_days` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- 2. Insert default 'Trial' plan
INSERT IGNORE INTO `subscription_plans` (`id`, `name`, `price`, `description`, `billing_cycle`, `trial_days`) 
VALUES ('trial-plan-uuid-001', 'Trial', 0.00, 'Free 14-day trial for new pharmacies', 'monthly', 14);

-- 3. Create EPS Settings table (Gateway Credentials)
CREATE TABLE IF NOT EXISTS `eps_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `environment` enum('sandbox', 'production') NOT NULL DEFAULT 'sandbox',
  -- Production Credentials
  `production_api_base_url` varchar(255) DEFAULT 'https://pgapi.eps.com.bd/v1',
  `production_username` varchar(255) DEFAULT NULL,
  `production_password` varchar(255) DEFAULT NULL,
  `production_merchant_id` varchar(255) DEFAULT NULL,
  `production_store_id` varchar(255) DEFAULT NULL,
  `production_hash_key` varchar(255) DEFAULT NULL,
  -- Sandbox Credentials
  `sandbox_api_base_url` varchar(255) DEFAULT 'https://pgsandboxapi.eps.com.bd/v1',
  `sandbox_username` varchar(255) DEFAULT NULL,
  `sandbox_password` varchar(255) DEFAULT NULL,
  `sandbox_merchant_id` varchar(255) DEFAULT NULL,
  `sandbox_store_id` varchar(255) DEFAULT NULL,
  `sandbox_hash_key` varchar(255) DEFAULT NULL,
  -- Redirect URLs
  `success_url` varchar(255) DEFAULT NULL,
  `fail_url` varchar(255) DEFAULT NULL,
  `cancel_url` varchar(255) DEFAULT NULL,
  `created_at` timestamp DEFAULT current_timestamp(),
  `updated_at` timestamp DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Create Payments tracking table
CREATE TABLE IF NOT EXISTS `payments` (
  `id` varchar(36) NOT NULL,
  `pharmacy_id` varchar(36) NOT NULL,
  `plan_id` varchar(36) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `merchant_transaction_id` varchar(255) NOT NULL,
  `eps_transaction_id` varchar(255) DEFAULT NULL,
  `payment_status` enum('pending', 'completed', 'failed', 'cancelled') DEFAULT 'pending',
  `payment_date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `merchant_transaction_id` (`merchant_transaction_id`),
  CONSTRAINT `fk_payments_pharmacy` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_payments_plan` FOREIGN KEY (`plan_id`) REFERENCES `subscription_plans` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- 5. Seed default EPS settings (Sandbox) if empty
INSERT INTO `eps_settings` (`environment`, `sandbox_api_base_url`, `success_url`, `fail_url`, `cancel_url`)
SELECT 'sandbox', 'https://pgsandboxapi.eps.com.bd/v1', 'https://your-domain.com/eps_callback.php?status=success', 'https://your-domain.com/eps_callback.php?status=fail', 'https://your-domain.com/eps_callback.php?status=cancel'
WHERE NOT EXISTS (SELECT 1 FROM `eps_settings`);

-- 6. Create coupons if it doesn't exist
CREATE TABLE IF NOT EXISTS `coupons` (
  `id` varchar(36) NOT NULL,
  `code` varchar(50) NOT NULL,
  `free_days` int(11) DEFAULT 0,
  `discount_percent` decimal(5,2) DEFAULT 0.00,
  `max_uses` int(11) DEFAULT NULL,
  `used_count` int(11) DEFAULT 0,
  `expires_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- 4. Safely rename subscriptions to subscribers
-- We use a procedure to check if the table exists before renaming
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS RenameSubscriptions()
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'subscriptions') THEN
        RENAME TABLE `subscriptions` TO `subscribers`;
    END IF;
END //
DELIMITER ;
CALL RenameSubscriptions();
DROP PROCEDURE IF EXISTS RenameSubscriptions;

-- 7. Add new columns to subscribers (if they don't exist)
SET @dbname = DATABASE();
SET @tablename = 'subscribers';

-- Add plan_id
SET @columnname = 'plan_id';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname, ' varchar(36) AFTER pharmacy_id')
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add is_paid
SET @columnname = 'is_paid';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname, ' tinyint(1) DEFAULT 0 AFTER status')
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add payment_ref
SET @columnname = 'payment_ref';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname, ' varchar(255) DEFAULT NULL AFTER is_paid')
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add coupon_id
SET @columnname = 'coupon_id';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname, ' varchar(36) DEFAULT NULL AFTER payment_ref')
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 6. Link existing subscribers to the 'Trial' plan
UPDATE `subscribers` SET `plan_id` = 'trial-plan-uuid-001' WHERE `plan_id` IS NULL;

-- 7. Drop redundant columns from subscribers (if they exist)
SET @columnname = 'plan_name';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  CONCAT('ALTER TABLE ', @tablename, ' DROP COLUMN ', @columnname),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @columnname = 'billing_cycle';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  CONCAT('ALTER TABLE ', @tablename, ' DROP COLUMN ', @columnname),
  'SELECT 1'
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 8. Refresh Foreign Key constraints
-- Note: We use a block to avoid errors if FK already exists.
ALTER TABLE `subscribers` DROP FOREIGN KEY IF EXISTS `subscribers_ibfk_2`;
ALTER TABLE `subscribers` DROP FOREIGN KEY IF EXISTS `subscribers_ibfk_3`;

ALTER TABLE `subscribers`
  ADD CONSTRAINT `subscribers_ibfk_2` FOREIGN KEY (`plan_id`) REFERENCES `subscription_plans` (`id`),
  ADD CONSTRAINT `subscribers_ibfk_3` FOREIGN KEY (`coupon_id`) REFERENCES `coupons` (`id`);

COMMIT;
