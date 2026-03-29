# PLAN: Bangla i18n — Remaining Screen Coverage

> **Status:** Ready for implementation
> **Scope:** 7 screens + 1 widget file fully missing `LanguageProvider`
> **Goal:** Complete the Bangla / English localization for all remaining screens

---

## 🔍 Debug Report

### Root Cause

The initial i18n implementation covered ~12 of 22 screens. The remaining screens were either added later or intentionally deferred. None of them import `LanguageProvider` and all contain hardcoded English strings.

### Coverage Status

| Screen | LanguageProvider? | Hardcoded Strings | Priority |
|--------|-------------------|-------------------|----------|
| `notification_screen.dart` | ❌ No | 4 | HIGH |
| `top_products_screen.dart` | ❌ No | 4 | HIGH |
| `restock_screen.dart` | ❌ No | 10 | HIGH |
| `profile_screen.dart` | ❌ No | 16 | HIGH |
| `edit_product_screen.dart` | ❌ No | 12 | HIGH |
| `bulk_import_screen.dart` | ❌ No | 15+ | MEDIUM |
| `bulk_import_edit_form.dart` | ❌ No | ~10 | MEDIUM |
| `subscription_screen.dart` | ❌ No | 7 | LOW (payment UI, EN-only is acceptable) |
| Already Covered Screens | ✅ Yes | — | Done |

---

## 📋 Hardcoded String Inventory by Screen

### 1. `notification_screen.dart`
```
'Notifications'                     → l10n.notificationsTitle
'No new notifications'              → l10n.noNotifications
'Low Stock Alerts'                  → l10n.lowStockTitle
'Expiring Soon'                     → l10n.expiringSoonTitle
'Item is low on stock (${...} strips left)'  → NEW: l10n.lowStockSubtitle(strips)
'Expires on ${...}'                 → NEW: l10n.expiresOnDate(date)
```

### 2. `top_products_screen.dart`
```
['Today', 'Week', 'Month', 'Year', 'All Time'] filter chips  → NEW keys
'No sales data for this period'     → l10n.noSalesData (already exists)
'REVENUE'                           → NEW: l10n.revenueLabel
'${...} boxes sold'                 → NEW: l10n.boxesSoldSuffix(n)
```

### 3. `restock_screen.dart`
```
'Restock'  (AppBar title)           → l10n.restockTitle (already exists)
'Please select an expiry date.'     → NEW: l10n.pleaseSelectExpiryDate
'Enter boxes or strips to add.'     → NEW: l10n.enterBoxesOrStrips
'Stock added successfully!'         → l10n.restockSuccess (already exists)
'Failed to add stock. Please try again.' → NEW: l10n.failedToAddStock
'Current stock: ${...}'             → NEW: l10n.currentStock(boxes, strips, pcs)
'Current expiry (product): ${...}'  → NEW: l10n.currentExpiry(date)
'Packaging: ${...} strips/box • ...'→ NEW: l10n.packagingInfo(spb, pps)
'Batch & expiry'  (section title)   → NEW: l10n.batchAndExpiry
'Quantity to add' (section title)   → NEW: l10n.quantityToAdd
'Batch No (optional)'               → NEW: l10n.batchNoOptional
'New batch exp: ${...}'             → NEW: l10n.newBatchExp(date)
'Select expiry for new batch*'      → NEW: l10n.selectExpiryForBatch
'Boxes' / 'Strips'  (field labels)  → l10n.boxes / l10n.strips (both already exist)
'Adding…' / 'Add stock'             → NEW: l10n.addingLabel / l10n.addStock
```

### 4. `profile_screen.dart`
```
'Account Information'               → l10n.accountInfo (already exists)
'Email Address'                     → NEW: l10n.emailAddress
'Subscription Valid Until'          → NEW: l10n.subscriptionValidUntil
'Subscription Management'           → NEW: l10n.subscriptionManagement
'Active Subscription'               → NEW: l10n.activeSubscription
'Expired / Inactive'                → NEW: l10n.expiredInactive
'Renew' / 'Activate'                → l10n.renewBtn / NEW: l10n.activateBtn
'Renewal Date'                      → NEW: l10n.renewalDate
'Edit Display Name'                 → NEW: l10n.editDisplayName
'Update Admin PIN'                  → NEW: l10n.updateAdminPin
'Set Local Password'                → NEW: l10n.setLocalPassword
'Create a password to also log in via email' → NEW: l10n.setLocalPasswordSubtitle
'Google Managed Account'            → NEW: l10n.googleManagedAccount
'You log in using your Google identity' → NEW: l10n.googleManagedSubtitle
'New Display Name' (field)          → NEW: l10n.newDisplayName
'Name is required'                  → NEW: l10n.nameRequired
'Max 100 characters'                → NEW: l10n.max100Chars
'Current PIN' / 'New PIN' / 'Confirm PIN' → NEW keys
'Update Security PIN' / 'Save Name' / 'Secure Local Account' → NEW keys
'New Password' / 'Confirm Password' → NEW keys
'Pin updated successfully!'         → NEW: l10n.pinUpdated
'Incorrect current PIN.'            → NEW: l10n.incorrectPin
'Name updated successfully!'        → NEW: l10n.nameUpdated
'Password set successfully!'        → l10n.passwordUpdated (already exists)
'Required' / 'Min 4 digits' / 'Min 8 characters' → NEW keys
'PINs do not match' / 'Passwords do not match' → NEW keys
```

### 5. `edit_product_screen.dart`
```
'Edit: ${product.name}' (AppBar)    → NEW: l10n.editProductTitle(name)
'Product Details' (section)         → l10n.editProduct (already exists)
'Product Name' (field)              → l10n.productName (already exists)
'Generic / Description'             → NEW: l10n.genericDescription
'Company Name (optional)'           → NEW: l10n.companyNameOptional
'Supplier Name (optional)'          → NEW: l10n.supplierNameOptional
'Supplier Phone (optional)'         → NEW: l10n.supplierPhoneOptional
'Barcode (optional)'                → NEW: l10n.barcodeOptional
'Expiry Date (optional)'            → NEW: l10n.expiryDateOptional
'Price / Strip' / 'Price / Pc'      → NEW: l10n.pricePerStripLabel / l10n.pricePerPcLabel
'Pieces per Strip'                  → l10n.pcsPerStrip (already exists)
'Low Stock Warning (Box)'           → NEW: l10n.lowStockWarningBox
'Active Batches' (section)          → NEW: l10n.activeBatches
'No active batches. Stock is 0.'    → NEW: l10n.noActiveBatches
'Batch: ${batch.batchNumber}'       → NEW: l10n.batchLabel (already exists in AppStrings)
'Exp: ${date}'                      → l10n.exp (already exists)
'${n} pcs'                          → NEW: l10n.pcsSuffix(n)
'Save Changes' (button)             → NEW: l10n.saveChanges
'Product updated successfully!'     → l10n.productUpdated (already exists)
'Required' (validators)             → NEW: l10n.requiredField (already exists)
'Medicine Type' (dropdown)          → NEW: l10n.medicineType
'Scan' (button)                     → l10n.scan (already exists)
```

### 6. `bulk_import_screen.dart`
```
'Bulk Import Preview' (AppBar)      → l10n.bulkImport (already exists)
'No file selected' / 'File: $_fileName' → NEW: l10n.noFileSelected / l10n.selectedFile(name)
'Select CSV/Excel' / 'Change'       → NEW: l10n.selectCsvExcel / l10n.changeBtn (exists)
'Show file structure example'       → NEW: l10n.showFileStructure
'Upload a CSV or Excel...' (hint)   → NEW: l10n.uploadCsvHint
'Legacy .xls files are not supported...' → NEW: l10n.xlsNotSupported
'Unsupported file type: ...'        → NEW: l10n.unsupportedFileType(ext)
'Ready to Import (${n})'            → NEW: l10n.readyToImport(n)
'Errors (${n})'                     → NEW: l10n.errorsCount(n)
'Confirm Import' (dialog title)     → NEW: l10n.confirmImport
'Are you sure you want to import ${n} items...' → NEW: l10n.confirmImportMsg(n)
'Cancel' / 'Yes, import'            → l10n.cancelBtn / NEW: l10n.yesImport
'Import ${n} Items' (button)        → NEW: l10n.importNItems(n)
'No valid products found.'          → NEW: l10n.noValidProducts
'No errors found! You are good to go.' → NEW: l10n.noErrorsFound
'Box Price' / 'Stock Pcs' / 'Barcode' / 'Type' (mini stats) → NEW keys
```

### 7. `bulk_import_edit_form.dart`
> Needs a separate file read for exact strings, but estimated ~10 hardcoded strings with field labels similar to `edit_product_screen`.

---

## 🗂️ New Keys Required in `app_strings.dart`

A total of **~65 new keys** need to be added. They should be grouped as follows:

```
// ── Notifications ─────────────────────────────
String lowStockSubtitle(int strips);
String expiresOnDate(String date);

// ── Top Products ───────────────────────────────
String get topProductsToday;
String get topProductsWeek;
String get topProductsMonth;
String get topProductsYear;
String get topProductsAllTime;
String get revenueLabel;
String boxesSoldSuffix(double n);

// ── Restock Screen ─────────────────────────────
String get pleaseSelectExpiryDate;
String get enterBoxesOrStrips;
String get failedToAddStock;
String currentStock(int boxes, int strips, int pcs);
String currentExpiry(String date);
String packagingInfo(int spb, int pps);
String get batchAndExpiry;
String get quantityToAdd;
String get batchNoOptional;
String newBatchExp(String date);
String get selectExpiryForBatch;
String get addingLabel;
String get addStock;

// ── Profile Screen ─────────────────────────────
String get emailAddress;
String get subscriptionValidUntil;
String get subscriptionManagement;
String get activeSubscription;
String get expiredInactive;
String get activateBtn;
String get renewalDate;
String get editDisplayName;
String get updateAdminPin;
String get setLocalPassword;
String get setLocalPasswordSubtitle;
String get googleManagedAccount;
String get googleManagedSubtitle;
String get newDisplayName;
String get nameRequired;
String get max100Chars;
String get currentPin;
String get newPin;
String get confirmPin;
String get pinUpdated;
String get incorrectPin;
String get nameUpdated;
String get saveNameBtn;
String get updateSecurityPin;
String get secureLocalAccount;
String get newPassword;       // already exists (passwordLabel)?
String get confirmPassword;   // already exists?
String get pinsDoNotMatch;
String get minFourDigits;

// ── Edit Product Screen ─────────────────────────
String get genericDescription;
String get companyNameOptional;
String get supplierNameOptional;
String get supplierPhoneOptional;
String get barcodeOptional;
String get expiryDateOptional;
String get pricePerStripLabel;
String get pricePerPcLabel;
String get lowStockWarningBox;
String get activeBatches;
String get noActiveBatches;
String pcsSuffix(int n);
String get saveChanges;
String get medicineType;
String editProductTitle(String name);

// ── Bulk Import Screen ──────────────────────────
String get noFileSelected;
String selectedFile(String name);
String get selectCsvExcel;
String get showFileStructure;
String get uploadCsvHint;
String get xlsNotSupported;
String unsupportedFileType(String ext);
String readyToImport(int n);
String errorsCount(int n);
String get confirmImport;
String confirmImportMsg(int n);
String get yesImport;
String importNItems(int n);
String get noValidProducts;
String get noErrorsFound;
String get boxPrice;
String get stockPcsLabel;
```

---

## 🏗️ Implementation Phases

### Phase 1: Update `app_strings.dart` (abstract contract)
- Add all ~65 new keys to the abstract class
- Group by screen for readability

### Phase 2: Update `app_strings_en.dart`
- Fill in all English translations (straightforward copy from existing hardcoded strings)

### Phase 3: Update `app_strings_bn.dart`
- Fill in all Bangla translations for every new key
- Follow the existing Bangla style (formal, consistent with the rest of the file)

### Phase 4: Screen-by-screen Migration (in priority order)

| Order | Screen | File | Approx. Lines Changed |
|-------|--------|------|-----------------------|
| 1 | Notification Screen | `notification_screen.dart` | ~10 |
| 2 | Top Products Screen | `top_products_screen.dart` | ~10 |
| 3 | Restock Screen | `restock_screen.dart` | ~25 |
| 4 | Profile Screen | `profile_screen.dart` | ~45 |
| 5 | Edit Product Screen | `edit_product_screen.dart` | ~35 |
| 6 | Bulk Import Screen | `bulk_import_screen.dart` | ~40 |
| 7 | Bulk Import Edit Form | `bulk_import_edit_form.dart` | ~25 |

**For each screen:**
1. Add `import '../../providers/language_provider.dart';`
2. Add `final l10n = context.read<LanguageProvider>().strings;` or `context.watch<LanguageProvider>().strings;` at the top of `build()`
3. Replace each hardcoded string with `l10n.<key>`

### Phase 5: Verification
- Hot-reload, switch language in Settings to Bangla
- Walk through each screen to confirm all visible text switches
- Run `dart analyze` to confirm zero new lint errors

---

## 📁 Files to Modify

| File | Change Type |
|------|-------------|
| `lib/l10n/app_strings.dart` | Add ~65 abstract keys |
| `lib/l10n/app_strings_en.dart` | Add ~65 English values |
| `lib/l10n/app_strings_bn.dart` | Add ~65 Bangla values |
| `lib/screens/admin/notification_screen.dart` | Wire to l10n |
| `lib/screens/admin/top_products_screen.dart` | Wire to l10n |
| `lib/screens/admin/restock_screen.dart` | Wire to l10n |
| `lib/screens/admin/profile_screen.dart` | Wire to l10n |
| `lib/screens/admin/edit_product_screen.dart` | Wire to l10n |
| `lib/screens/admin/bulk_import_screen.dart` | Wire to l10n |
| `lib/screens/admin/bulk_import_edit_form.dart` | Wire to l10n |

---

## # Finalizing Pharmacy POS Localization

- [x] Audit all screens for hardcoded strings
- [/] Localize remaining 5 screens
  - [/] Update `AppStrings` with new keys
  - [ ] Localize `expiring_soon_screen.dart`
  - [ ] Localize `low_stock_screen.dart`
  - [ ] Localize `manual_add_screen.dart`
  - [ ] Localize `ocr_scan_result_screen.dart`
  - [ ] Localize `subscription_screen.dart`
- [ ] Final regression test and verification
