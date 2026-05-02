# Pharmacy POS — Feature Reference

This document describes capabilities implemented in the **Pharmacy POS** Flutter application and its companion PHP backend. It reflects the codebase structure (screens, services, and APIs) as of the repository state where this file was added.

---

## Product overview

- **Local-first POS**: Inventory, batches, sales history, and cart logic run on-device using **SQLite** (`sqflite`; desktop uses FFI).
- **Currency & locale**: Checkout and reports use the **Bangladesh Taka (৳)** symbol in the UI; the app supports **English** and **Bangla** (`LanguageProvider`, localized strings).
- **Platforms**: Mobile (Android/iOS) with barcode camera, OCR, voice, and alarms; **Windows** builds skip the live barcode camera on home (desktop-appropriate behavior). Linux/macOS use desktop database paths where applicable.

---

## Authentication and session

| Capability | Detail |
|------------|--------|
| **Email / password** | Register and log in via backend (`local_register.php`, `local_login.php`); JWT-style access with refresh token (`refresh_token.php`). |
| **Google Sign-In** | Optional Google account linking; shared session supports silent sign-in for related flows (e.g. Drive scope). |
| **Device identity** | Hardware UID and device descriptors sent at login for server-side device tracking (`device_info_plus`). |
| **Startup validation** | Splash screen refreshes tokens when online; invalid credentials force re-login; transient server errors allow offline continuation with cached session. |
| **Logout** | Clears stored credentials from secure storage and returns to login. |

---

## Subscription and payments

| Capability | Detail |
|------------|--------|
| **Plans** | Subscription plans loaded from `get_plans.php`; UI supports monthly/yearly-style selection where implemented. |
| **Checkout** | Payments initiated via **EPS** (`eps_initialize.php`, `eps_verify.php`, `eps_callback.php`) inside an in-app **WebView**. |
| **Coupons** | Codes validated against `validate_coupon.php`; discounted or free flows wired through `EpsService` / subscription UI. |
| **Access control** | Expired subscriptions can block normal app entry (`SplashScreen`, `HomeScreen`, dedicated `SubscriptionScreen`). |
| **Cron** | Server-side expiry handling referenced via `subscription_expiry_cron.php`. |

---

## Point of sale (home screen)

| Capability | Detail |
|------------|--------|
| **Barcode scanning** | Live camera scanner (`mobile_scanner`) with torch and lifecycle-aware start/stop when navigating away or collapsing the scanner. |
| **Cart** | Line items with strip/piece/box pricing consistent with product definitions; totals shown in footer (`PosCheckoutFooter`). |
| **Manual add** | Browse/filter inventory and add quantities without scanning (`ManualAddScreen`). |
| **OCR** | Capture strip/packaging text with the device camera; **ML Kit** text recognition parses candidates into products (`OcrService`, `OcrScanResultScreen`). Long-press / debug flows may expose `OcrDebugScreen`. |
| **Voice search** | Continuous listening session maps spoken phrases to products using phonetic-style matching (`ContinuousVoiceSessionService`, `SpeechService`, `ProductMatcher`). |
| **Inline search** | Text search with overlay suggestions over the catalog. |
| **Checkout** | Completes a sale locally (stock deduction, sale records); integrates **replacement checkout** when returning goods tie to an invoice (`POSProvider.completeReplacementSale`). |
| **Stock guards** | Warns when cart quantities exceed available stock (`OutOfStockDialog`). |
| **Selling device policy** | Checkout may require the device to be the **active seller** on the account (`InactiveSellingDeviceException`); prompts refresh from server. |

---

## Inventory and pharmacy data model

Products support pharmacy-oriented fields including:

- Identity: name, generic name, barcode, company.
- Packaging: pieces per strip, strips per box, optional box selling price.
- Pricing: strip/piece/box customer prices; **cost per piece** for margin reporting.
- Stock: strips/pieces (derived boxes); **FIFO-style batches** with batch numbers and expiry (`StockBatch`, `product_batches`).
- Supplier: name and phone (optional visibility toggle).
- Classification: **medicine type** and **power/strength** (used in notifications and labels).

**Duplicate handling**: Database migrations/helpers can merge duplicate product rows by name and reattach batches.

---

## Admin portal

Access is gated behind **admin authentication** (PIN dialog from drawer / dashboard entry). Additional options include:

- **Biometric unlock** (`local_auth`) where configured in Settings, as an alternative to PIN.
- **Admin PIN management** backed by APIs such as `admin_pin.php`, OTP flows (`verify_admin_pin_otp.php`, `request_admin_pin_reset.php`, `reset_admin_pin_with_otp.php`), and password-assisted reset (`reset_admin_pin_with_password.php`).
- **Dashboard navigation**: Overview plus embedded sections — product list, add product, low stock, expiring soon, returns, sales report, profit report, top products, settings, profile (`AdminDashboardScreen`).

---

## Screens and workflows (by area)

### POS drawer (non-admin)

- Home, **product list** (browse-only mode), **returns**, **low stock**, **expiring soon**, **admin portal** entry, **logout**.
- Drawer header shows **Google Drive backup sync status** when Drive integration is in use.

### Product lifecycle

- **Add / edit product** with collapsible field groups, stepper vs. free-form entry (configurable default).
- **Product list** with search/filters (`right_filter_panel` patterns where used).
- **Restock**: Receive stock against batches with pricing sections that can collapse by default (setting).
- **Bulk import**: CSV or Excel with a defined column schema (`BulkImportScreen`); preview/edit step (`bulk_import_edit_form.dart`).

### Alerts and notifications

- **Low stock** and **expiring soon** standalone screens mirror threshold-driven lists from settings.
- **Notification screen**: Aggregates low-stock and expiry alerts; marks alerts read when opened.
- **Local notifications** (`NotificationService`, `flutter_local_notifications`) plus **timezone-aware** scheduling helpers.
- **Alarms**: `alarm` package integration; ringing fires navigation to **`AlarmAlertScreen`** (`/alarm_alert` route); payloads describe alarm slots (`AlarmSlot`).

### Reporting and exports

- **Sales report**: Filterable history with charts (`fl_chart`).
- **Profit report**: Uses cost vs. revenue assumptions from product cost fields.
- **Top products**: Ranking/analytics view.
- **Export**: CSV, PDF, and Excel export pipelines (`ExportService`, `printing`, `file_saver`) with optional directory preferences (`ExportSaveHelper`, `export_save_directory.dart`).

### Returns

- **Returns** flow reduces/restocks appropriately and can drive a **replacement sale** checkout path on the home screen (`replacementSourceInvoiceNumber` / provider state).

---

## Settings (four tabs)

1. **General**  
   - UI language (English / Bangla).  
   - **Display & behavior**: show supplier info on relevant screens; default stepper mode for add-product; restock pricing panel collapsed by default.

2. **Inventory alerts**  
   - Low-stock threshold.  
   - Expiry tiers: warning / moderate / critical day counts and ordering validation (critical ≤ moderate ≤ warning).  
   - **Expiry delay months** for scheduling-related logic.  
   - Defaults for **boxes to order** and **strips per box** used in ordering/restock contexts.

3. **Alarms**  
   - Configure named alarm slots (times/reminders) persisted locally and wired to the alarm scheduler.

4. **Security & data**  
   - **Google Drive**: Backup SQLite to Drive (`drive.file` scope); restore prompts exist from login bootstrap (`AdminProvider.checkAndRestoreFromDrive`).  
   - **Manual backup**: Export/import `.db` or related backup files via picker (`file_picker`).  
   - **Database location**: Android **SAF** tree or public DB preparation via platform channel (`pharmacy_pos/db_storage`); desktop optional folder via `DbLocationService`.  
   - **Biometric** toggle for admin entry.

---

## Integrity and observability

| Capability | Detail |
|------------|--------|
| **Time lock** | `TimeLockBarrier` blocks the app if device time appears tampered (backward jumps) or drifts too far from server time (`TimeService`, `get_time.php`). |
| **Analytics** | Microsoft **Clarity** wrapper around the app (`clarity_flutter`). |
| **Connectivity** | `connectivity_plus` used where network-aware behavior is needed. |

---

## Backend API summary

| Area | Endpoints (examples) |
|------|----------------------|
| Auth | `local_login.php`, `local_register.php`, `refresh_token.php`, `google_login.php`, `set_password.php` |
| Device / seller | `list_devices.php`, `switch_active_device.php`, `verify_active_seller.php`, `check_access.php` |
| Profile | `update_profile.php` |
| Subscription / pay | `get_plans.php`, `eps_initialize.php`, `eps_verify.php`, `eps_callback.php`, `validate_coupon.php`, `apply_free_coupon.php`, `subscription_expiry_cron.php` |
| Admin PIN | `admin_pin.php`, `request_admin_pin_reset.php`, `verify_admin_pin_otp.php`, `reset_admin_pin_with_otp.php`, `reset_admin_pin_with_password.php` |
| Time | `get_time.php` |

*(Shared helpers: `config.php`, `device_auth_helper.php`, `mail_helper.php`, `eps_helper.php`.)*

---

## Dependencies that map to user-visible features

- **Scanning / media**: `mobile_scanner`, `image_picker`, `google_mlkit_text_recognition`  
- **Speech**: `speech_to_text`  
- **Storage & files**: `sqflite`, `path_provider`, `file_picker`, `shared_preferences`, `flutter_secure_storage`  
- **Export & print**: `pdf`, `printing`, `csv`, `excel`, `file_saver`, `open_file`  
- **Auth & identity**: `google_sign_in`, `local_auth`, `crypto`  
- **Scheduling**: `flutter_local_notifications`, `timezone`, `alarm`  
- **Networking**: `http`  

---

## How to keep this document accurate

When you add a screen, setting, API route, or user-facing workflow, append a short row to the relevant section above (or add a subsection). This file is descriptive only; it does not replace API contracts or deployment runbooks.
