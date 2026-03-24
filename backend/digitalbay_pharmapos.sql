-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Mar 15, 2026 at 05:39 PM
-- Server version: 11.4.10-MariaDB
-- PHP Version: 8.4.16

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `digitalbay_pharmapos`
--

-- --------------------------------------------------------

--
-- Table structure for table `devices`
--

CREATE TABLE `devices` (
  `id` varchar(36) NOT NULL,
  `pharmacy_id` varchar(36) NOT NULL,
  `hardware_uid` varchar(255) NOT NULL,
  `device_name` varchar(100) DEFAULT NULL,
  `last_login_at` timestamp NULL DEFAULT current_timestamp(),
  `is_authorized` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `pharmacies`
--

CREATE TABLE `pharmacies` (
  `id` varchar(36) NOT NULL,
  `business_name` varchar(100) NOT NULL,
  `owner_name` varchar(100) NOT NULL,
  `contact_phone` varchar(20) NOT NULL,
  `contact_email` varchar(100) NOT NULL,
  `account_status` enum('trial','active','suspended','canceled') DEFAULT 'trial',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Table structure for table `subscription_plans`
--

CREATE TABLE `subscription_plans` (
  `id` varchar(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `description` text DEFAULT NULL,
  `billing_cycle` enum('monthly','yearly','lifetime') NOT NULL,
  `trial_days` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Table structure for table `coupons`
--

CREATE TABLE `coupons` (
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

--
-- Table structure for table `subscribers`
--

CREATE TABLE `subscribers` (
  `id` varchar(36) NOT NULL,
  `pharmacy_id` varchar(36) NOT NULL,
  `plan_id` varchar(36) NOT NULL,
  `valid_until` datetime NOT NULL,
  `last_sync_at` datetime DEFAULT NULL,
  `status` enum('active','past_due','expired') DEFAULT 'active',
  `coupon_id` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `pharmacy_id` (`pharmacy_id`),
  KEY `plan_id` (`plan_id`),
  KEY `coupon_id` (`coupon_id`),
  KEY `idx_valid_until` (`valid_until`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` varchar(36) NOT NULL,
  `pharmacy_id` varchar(36) NOT NULL,
  `role` enum('owner','manager','cashier') DEFAULT 'cashier',
  `email` varchar(100) NOT NULL,
  `auth_provider` enum('local','google','apple') DEFAULT 'local',
  `oauth_uid` varchar(255) DEFAULT NULL,
  `password_hash` varchar(255) DEFAULT NULL,
  `full_name` varchar(100) DEFAULT NULL,
  `avatar_url` text DEFAULT NULL,
  `pin_code` varchar(10) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `devices`
--
ALTER TABLE `devices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `hardware_uid` (`hardware_uid`),
  ADD KEY `pharmacy_id` (`pharmacy_id`);

--
-- Indexes for table `pharmacies`
--
ALTER TABLE `pharmacies`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `contact_email` (`contact_email`);

--
-- Indexes for table `subscribers`
--
ALTER TABLE `subscribers`
  ADD CONSTRAINT `subscribers_ibfk_1` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `subscribers_ibfk_2` FOREIGN KEY (`plan_id`) REFERENCES `subscription_plans` (`id`),
  ADD CONSTRAINT `subscribers_ibfk_3` FOREIGN KEY (`coupon_id`) REFERENCES `coupons` (`id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `oauth_uid` (`oauth_uid`),
  ADD KEY `pharmacy_id` (`pharmacy_id`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `devices`
--
ALTER TABLE `devices`
  ADD CONSTRAINT `devices_ibfk_1` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`id`) ON DELETE CASCADE;

-- Removed redundant subscriptions_ibfk_1 (handled in subscribers table)

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `users_ibfk_1` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
