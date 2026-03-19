# Pharmacy POS - Development Guidelines & Constraints

## Core Tech Stack
* **Framework:** Flutter (Dart).
* **State Management:** `provider` exclusively. No BLoC, Riverpod, or overly complex alternatives.
* **Local Database:** `sqlite` (`sqflite` plugin) for offline-first data, stock tracking, and POS operations.

## Features & Dependencies
* **Barcode/QR Scanner:** `mobile_scanner` (uses Apple Vision / Google ML Kit). **Strictly no** `qr_code_scanner` or `barcode_scan2`.
* **Haptics & Audio Feedback:** `vibration` and `audioplayers` must be utilized. Every successful scan must have a clear "beep" and physical phone vibration to ensure the cashier isn't slowed down by checking the screen.
* **Icons:** `lucide_icons` to maintain a sharp, modern look matching the original React prototype.

## UI/Theme Constraints
* **Material Design:** Disable Material 3 dynamic coloring (`useMaterial3: false`) OR heavily override colors to protect the chosen palette. No pastel or Android default theme overrides.
* **Color Palette (Strict):**
  * Background: `#F7F8F0` (Cream/Off-White)
  * Primary Dark: `#355872` (Slate Blue)
  * Secondary/Accent: `#7AAACE` (Soft Blue)
  * Highlight/Active: `#9CD5FF` (Bright Blue)

## System Architecture & Data Flow
1. **Authentication:** Initial login via custom server authentication.
2. **Offline-first operation:** The app runs primarily on local SQLite storage to ensure uninterrupted POS usage.
3. **Data Sync:** 
   * Local DB syncs to Google Drive using the user's available 15GB by default.
   * Premium users can opt to sync data to our managed server storage instead.
4. **Stock Tracking:** App must include features to add stock, track inventory, and push warnings for low stock & expiry dates.
