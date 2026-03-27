# PLAN: Bangla + English Localization (i18n)

## Goal

Add full Bangla (বাংলা) support alongside English to the Pharmacy POS Flutter app. All **system UI strings** (labels, button text, screen titles, messages, dialog text, snackbars) will be extracted into two Dart files — one per language. A toggle in the Settings screen persists the user's choice via `shared_preferences`.

---

## Decisions

| Decision | Choice | Reason |
|---|---|---|
| Implementation | Custom `AppStrings` abstract class | No codegen, minimal boilerplate, directly editable files |
| State management | `ChangeNotifier` provider | Already used project-wide |
| Persistence | `shared_preferences` | Already a dependency |
| Language toggle | Settings screen | User-controlled, persisted between sessions |
| String scope | Labels + messages (no user-entered data) | Medicine names, supplier names etc. excluded |

---

## Proposed File Structure

```
lib/
├── l10n/
│   ├── app_strings.dart          # [NEW] Abstract base class (all string keys)
│   ├── app_strings_en.dart       # [NEW] English strings
│   └── app_strings_bn.dart       # [NEW] Bangla strings
├── providers/
│   └── language_provider.dart    # [NEW] ChangeNotifier, persists lang choice
└── main.dart                     # [MODIFY] Register LanguageProvider
```

---

## Proposed Changes

---

### Component 1 — String Abstraction Layer

#### [NEW] `lib/l10n/app_strings.dart`

Abstract class defining every translatable string key as a `String get` abstract getter.

```dart
abstract class AppStrings {
  // ── Navigation ─────────────────────────────────────
  String get navDashboard;
  String get navAddProduct;
  String get navReturns;
  String get navSalesReport;
  String get navExpiringSoon;
  String get navLowStock;
  String get navProductList;
  String get navTopProducts;
  String get navSettings;
  String get navProfile;
  String get navNotifications;
  String get navBackToPos;

  // ── POS / Home Screen ──────────────────────────────
  String get appName;             // 'Pharmacy POS'
  String get saleComplete;
  String get clearCart;
  String get clearCartConfirm;
  String get newSale;
  String get cancelBtn;
  String get yesClr;
  String get addedToCart;         // 'Added {name} (1 pc) to cart'
  String get noMatchVoice;
  String get voiceError;
  String get barcodeNotFound;
  String get readingStrip;
  String get noMedicineDetected;
  String get ocrError;
  String get successCharged;      // 'Successfully charged {amount} Taka'
  String get listening;

  // ── Login Screen ───────────────────────────────────
  String get signInToStart;
  String get emailLabel;
  String get passwordLabel;
  String get signInBtn;
  String get continueWithGoogle;
  String get orCreateAccount;
  String get createPharmacyAccount;
  String get createAccountBtn;
  String get fullNameLabel;
  String get pharmacyNameLabel;
  String get passwordMinChars;    // 'Password (min 8 characters)'
  String get confirmPasswordLabel;
  String get validationEnterEmail;
  String get validationValidEmail;
  String get validationEnterPassword;
  String get validationPasswordMin;
  String get validationEnterName;
  String get validationEnterBusiness;
  String get validationConfirmPassword;
  String get validationPasswordsNoMatch;
  String get loginFailed;
  String get registrationFailed;
  String get googleSignInFailed;

  // ── Admin Dashboard ────────────────────────────────
  String get adminPortal;
  String get overview;
  String get todaysSales;
  String get totalOrders;
  String get lowStock;
  String get expiringSoon;
  String get criticalInventory;
  String get allStockGood;
  String get recentTransactions;
  String get lowStockBadge;
  String get expiringSoonBadge;
  String get unknownExpiry;       // 'Unknown Expiry'
  String get expiresPrefix;       // 'Expires: '
  String get notifications;
  String get logout;

  // ── Settings Screen ────────────────────────────────
  String get inventoryAlerts;
  String get lowStockThreshold;
  String get lowStockThresholdHelper;
  String get defaultBoxesToOrder;
  String get defaultBoxesHelper;
  String get expiringSoonWindow;
  String get expiringSoonWindowHelper;
  String get moderateExpiry;
  String get moderateExpiryHelper;
  String get criticalExpiry;
  String get criticalExpiryHelper;
  String get defaultExpiryDelay;
  String get defaultExpiryDelayHelper;
  String get showSupplierInfo;
  String get showSupplierInfoHelper;
  String get saveSettings;
  String get settingsSaved;
  String get expiryOrderError;

  // ── Settings — Database Backup ─────────────────────
  String get databaseBackup;
  String get googleDriveIntegration;
  String get googleDriveDesc;
  String get notSyncedYet;
  String get syncingNow;
  String get syncFailed;
  String get lastSync;            // 'Last sync: {date}'
  String get missingDriveScope;
  String get ensureSignedIn;
  String get syncNow;

  // ── Settings — Phone Backup ────────────────────────
  String get phoneStorageBackup;
  String get offlineBackupImport;
  String get offlineBackupDesc;
  String get exportNow;
  String get importDb;
  String get exportedSuccess;
  String get importDatabase;
  String get importDatabaseWarning;
  String get importReplace;
  String get importSuccess;
  String get importFailed;        // 'Import failed: {error}'

  // ── Settings — Medicine Categories ─────────────────
  String get medicineCategories;
  String get medicineCategoriesDesc;
  String get addNewType;          // hint: 'Add new type (e.g. Inhaler)'
  String get removeCategory;
  String get removeCategoryConfirm; // 'Are you sure you want to remove "{type}"?'
  String get removeCategoryWarning;
  String get removeBtn;

  // ── Language Setting (NEW) ─────────────────────────
  String get languageSetting;
  String get languageEnglish;
  String get languageBangla;

  // ── Returns Screen ─────────────────────────────────
  String get returnsTitle;
  String get filterReturns;
  String get dateRange;
  String get amountRange;
  String get timeRange;
  String get anyTime;
  String get applyBtn;
  String get clearTime;
  String get sortNewest;
  String get sortOldest;
  String get sortHighToLow;
  String get sortLowToHigh;
  String get returnItems;
  String get confirmReturn;
  String get noItemsInvoice;
  String get allItemsReturned;
  String get someProductsSkipped;
  String get couldNotFindProducts;
  String get returnItemsFor;       // 'Return items for {invoice}'
  String get strips;
  String get pcs;
  String get maxReturnable;        // 'Max returnable: {n} pcs'
  String get selected;             // 'Selected: {n} pcs'
  String get changeBtn;

  // ── Product List Screen ────────────────────────────
  String get productList;
  String get searchProducts;
  String get editBtn;
  String get restockBtn;
  String get noProductsFound;
  String get deleteProduct;
  String get deleteProductConfirm;
  String get deleteBtn;
  String get productDeleted;

  // ── Add / Edit Product Screen ──────────────────────
  String get addProduct;
  String get editProduct;
  String get productName;
  String get genericName;
  String get category;
  String get pricePerPc;
  String get pricePerStrip;
  String get pcsPerStrip;
  String get stockBoxes;
  String get pcsPerBox;
  String get minStockLevel;
  String get expiryDate;
  String get supplierName;
  String get supplierPhone;
  String get saveProduct;
  String get productSaved;
  String get productUpdated;
  String get requiredField;

  // ── Restock Screen ─────────────────────────────────
  String get restock;
  String get restockTitle;
  String get boxesToAdd;
  String get confirmRestock;
  String get restockSuccess;

  // ── Sales Report Screen ────────────────────────────
  String get salesReport;
  String get totalRevenue;
  String get totalTransactions;
  String get topProduct;
  String get noSalesData;
  String get exportPdf;
  String get exportCsv;
  String get exportSuccess;
  String get exportFailed;

  // ── Expiring Soon & Low Stock ──────────────────────
  String get expiringSoonTitle;
  String get lowStockTitle;
  String get exportOrderList;
  String get noExpiringSoon;
  String get noLowStock;
  String get remainingPcs;
  String get boxesSuffix;          // 'boxes'
  String get stripsSuffix;         // 'strips'

  // ── Notification Screen ────────────────────────────
  String get notificationsTitle;
  String get noNotifications;
  String get markAllRead;

  // ── Profile Screen ─────────────────────────────────
  String get profileTitle;
  String get signOut;
  String get signOutConfirm;
  String get accountInfo;
  String get changePassword;
  String get currentPassword;
  String get newPassword;
  String get updatePassword;
  String get passwordUpdated;

  // ── Subscription Screen ────────────────────────────
  String get subscriptionTitle;
  String get subscribeBtn;
  String get currentPlan;
  String get expiresOn;
  String get trialExpired;
  String get renewBtn;

  // ── OCR / Scan Result ──────────────────────────────
  String get ocrScanResult;
  String get addAllToCart;
  String get confirmedItems;

  // ── Common / Shared ────────────────────────────────
  String get loading;
  String get error;
  String get success;
  String get tryAgain;
  String get toLabel;             // 'to' (used in date/time range pickers)
  String get close;
  String get confirm;
  String get apply;
  String get search;
  String get filter;
  String get sort;
  String get noResultsFound;
  String get boxes;
  String get minAmount;           // 'Min ৳'
  String get maxAmount;           // 'Max ৳'
  String get backToPos;
}
```

---

#### [NEW] `lib/l10n/app_strings_en.dart`

English implementation of every key. This is the source of truth for English text.

#### [NEW] `lib/l10n/app_strings_bn.dart`

Bangla implementation using modern, everyday Bangla. **Full key→Bangla mapping list** (excerpt shown, all keys will be present):

| Key | English | বাংলা |
|-----|---------|-------|
| `navDashboard` | Dashboard | ড্যাশবোর্ড |
| `navAddProduct` | Add Product | পণ্য যোগ |
| `navReturns` | Returns | রিটার্ন |
| `navSalesReport` | Sales Report | বিক্রয় রিপোর্ট |
| `navExpiringSoon` | Expiring Soon | মেয়াদোত্তীর্ণ হচ্ছে |
| `navLowStock` | Low Stock | কম স্টক |
| `navProductList` | Product List | পণ্য তালিকা |
| `navTopProducts` | Top Products | সেরা পণ্য |
| `navSettings` | Settings | সেটিংস |
| `navProfile` | Profile | প্রোফাইল |
| `navNotifications` | Notifications | বিজ্ঞপ্তি |
| `navBackToPos` | Back to POS | POS-এ ফিরুন |
| `appName` | Pharmacy POS | ফার্মেসি POS |
| `saleComplete` | Sale Complete | বিক্রয় সম্পন্ন |
| `clearCart` | Clear Cart? | কার্ট মুছবেন? |
| `clearCartConfirm` | Are you sure you want to clear the cart? | আপনি কি কার্ট মুছতে চান? |
| `newSale` | New Sale | নতুন বিক্রয় |
| `cancelBtn` | Cancel | বাতিল |
| `yesClr` | Yes, Clear | হ্যাঁ, মুছুন |
| `noMatchVoice` | No match – edit the name and tap the search icon. | কোনো মিল নেই – নাম সম্পাদনা করুন। |
| `barcodeNotFound` | Product not found for barcode | বারকোডের পণ্য পাওয়া যায়নি |
| `readingStrip` | Reading strip... | স্ট্রিপ পড়া হচ্ছে... |
| `noMedicineDetected` | No medicine names detected. Try again. | কোনো ওষুধের নাম পাওয়া যায়নি। আবার চেষ্টা করুন। |
| `listening` | Listening... | শুনছি... |
| `signInToStart` | Sign in to start selling | বিক্রয় শুরু করতে সাইন ইন করুন |
| `signInBtn` | Sign in | সাইন ইন |
| `continueWithGoogle` | Continue with Google | Google দিয়ে চালিয়ে যান |
| `orCreateAccount` | Or create an account | অথবা অ্যাকাউন্ট তৈরি করুন |
| `createPharmacyAccount` | Create Pharmacy Account | ফার্মেসি অ্যাকাউন্ট তৈরি |
| `adminPortal` | ADMIN PORTAL | অ্যাডমিন পোর্টাল |
| `overview` | Overview | সংক্ষিপ্ত বিবরণ |
| `todaysSales` | Today's Sales | আজকের বিক্রয় |
| `totalOrders` | Total Orders | মোট অর্ডার |
| `lowStock` | Low Stock | কম স্টক |
| `expiringSoon` | Expiring Soon | মেয়াদোত্তীর্ণ হচ্ছে |
| `criticalInventory` | Critical Inventory | জরুরি তালিকা |
| `allStockGood` | All stock is good! 🎉 | সব স্টক ঠিক আছে! 🎉 |
| `recentTransactions` | Recent Transactions | সাম্প্রতিক লেনদেন |
| `logout` | Logout | লগআউট |
| `saveSettings` | Save Settings | সেটিংস সংরক্ষণ |
| `settingsSaved` | Settings saved successfully | সেটিংস সফলভাবে সংরক্ষিত হয়েছে |
| `databaseBackup` | Database Backup | ডেটাবেজ ব্যাকআপ |
| `syncNow` | Sync Now | এখনই সিঙ্ক করুন |
| `exportNow` | Export Now | রপ্তানি করুন |
| `importDb` | Import DB | DB আমদানি |
| `importSuccess` | Import successful! | আমদানি সফল! |
| `medicineCategories` | Medicine Categories | ওষুধের বিভাগ |
| `languageSetting` | Language | ভাষা |
| `languageEnglish` | English | English |
| `languageBangla` | বাংলা | বাংলা |
| `filterReturns` | Filter Returns | রিটার্ন ফিল্টার |
| `dateRange` | Date Range | তারিখ সীমা |
| `confirmReturn` | Confirm Return | রিটার্ন নিশ্চিত করুন |
| `sortNewest` | Newest First | সর্বশেষ আগে |
| `sortOldest` | Oldest First | পুরনো আগে |
| `salesReport` | Sales Report | বিক্রয় রিপোর্ট |
| `exportPdf` | Export PDF | PDF রপ্তানি |
| `exportCsv` | Export CSV | CSV রপ্তানি |
| `profileTitle` | Profile | প্রোফাইল |
| `signOut` | Sign Out | সাইন আউট |
| `subscriptionTitle` | Subscription | সাবস্ক্রিপশন |
| `loading` | Loading... | লোড হচ্ছে... |
| `error` | Error | ত্রুটি |
| `success` | Success | সফল |
| `search` | Search | অনুসন্ধান |
| `noResultsFound` | No results found | কোনো ফলাফল পাওয়া যায়নি |

*(All ~120 keys will have entries in both files)*

---

### Component 2 — Language Provider

#### [NEW] `lib/providers/language_provider.dart`

```dart
class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_language';
  AppStrings _strings = AppStringsEn();

  AppStrings get strings => _strings;
  bool get isBangla => _strings is AppStringsBn;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_key) ?? 'en';
    _strings = lang == 'bn' ? AppStringsBn() : AppStringsEn();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang);
    _strings = lang == 'bn' ? AppStringsBn() : AppStringsEn();
    notifyListeners();
  }
}
```

---

### Component 3 — Provider Registration

#### [MODIFY] `lib/main.dart`

Add `LanguageProvider` to the `MultiProvider` list and call `init()` before `runApp`.

---

### Component 4 — Settings Screen Toggle

#### [MODIFY] `lib/screens/admin/settings_screen.dart`

Add a `Language` section card (or append to existing Inventory Alerts card) with a `SegmentedButton` or two `ListTile` radio tiles for English / বাংলা.  
Calls `context.read<LanguageProvider>().setLanguage('bn')` on change.

---

### Component 5 — String Replacement (all screens)

Replace every hardcoded system string across **all** screens and key widgets with `context.read<LanguageProvider>().strings.<key>`.

**Screens affected:**

| File | String Keys Affected |
|------|---------------------|
| `home_screen.dart` | saleComplete, clearCart, newSale, cancelBtn, yesClr, addedToCart, noMatchVoice, voiceError, barcodeNotFound, readingStrip, noMedicineDetected, ocrError, successCharged, listening |
| `login_screen.dart` | appName, signInToStart, emailLabel, passwordLabel, signInBtn, continueWithGoogle, orCreateAccount, createPharmacyAccount, createAccountBtn, fullNameLabel, pharmacyNameLabel, confirmPasswordLabel, all validation messages, loginFailed, registrationFailed, googleSignInFailed |
| `admin_dashboard_screen.dart` | navDashboard...navProfile, adminPortal, overview, todaysSales, totalOrders, lowStock, expiringSoon, criticalInventory, allStockGood, recentTransactions, lowStockBadge, expiringSoonBadge, unknownExpiry, expiresPrefix, notifications, logout, backToPos |
| `settings_screen.dart` | All settings labels + helper texts, saveSettings, settingsSaved, expiryOrderError, databaseBackup, googleDriveIntegration, googleDriveDesc, syncNow, phoneStorageBackup, offlineBackupImport, offlineBackupDesc, exportNow, importDb, exportedSuccess, importDatabase, importDatabaseWarning, importReplace, importSuccess, importFailed, medicineCategories, medicineCategoriesDesc, addNewType, removeCategory, removeCategoryConfirm, removeCategoryWarning, removeBtn, languageSetting, languageEnglish, languageBangla |
| `returns_screen.dart` | returnsTitle, filterReturns, dateRange, amountRange, timeRange, anyTime, applyBtn, clearTime, sortNewest, sortOldest, sortHighToLow, sortLowToHigh, confirmReturn, cancelBtn, noItemsInvoice, allItemsReturned, someProductsSkipped, returnItemsFor, strips, pcs, maxReturnable, selected, changeBtn |
| `product_list_screen.dart` | productList, searchProducts, editBtn, restockBtn, noProductsFound, deleteProduct, deleteProductConfirm, deleteBtn, productDeleted |
| `add_product_screen.dart` | addProduct, productName, genericName, category, pricePerPc, pricePerStrip, pcsPerStrip, stockBoxes, pcsPerBox, minStockLevel, expiryDate, supplierName, supplierPhone, saveProduct, productSaved, requiredField |
| `edit_product_screen.dart` | editProduct, productUpdated, (same labels as add) |
| `restock_screen.dart` | restock, restockTitle, boxesToAdd, confirmRestock, restockSuccess |
| `sales_report_screen.dart` | salesReport, totalRevenue, totalTransactions, topProduct, noSalesData, exportPdf, exportCsv, exportSuccess, exportFailed |
| `expiring_soon_screen.dart` | expiringSoonTitle, exportOrderList, noExpiringSoon, remainingPcs, boxesSuffix, stripsSuffix |
| `low_stock_screen.dart` | lowStockTitle, exportOrderList, noLowStock, remainingPcs, boxesSuffix, stripsSuffix |
| `notification_screen.dart` | notificationsTitle, noNotifications, markAllRead |
| `profile_screen.dart` | profileTitle, signOut, signOutConfirm, accountInfo, changePassword, currentPassword, newPassword, updatePassword, passwordUpdated |
| `subscription_screen.dart` | subscriptionTitle, subscribeBtn, currentPlan, expiresOn, trialExpired, renewBtn |
| `ocr_scan_result_screen.dart` | ocrScanResult, addAllToCart, confirmedItems |
| Widgets in `lib/widgets/` | admin_login_dialog, subscription_warning_dialog, pos_drawer, out_of_stock_dialog |

---

### Component 6 — Bangla Font Support

#### [MODIFY] `pubspec.yaml` & `assets/` 

The app currently uses Roboto, which **does not support Bangla glyphs**. We need to add a Bangla-compatible font.

**Options:**
- **`google_fonts` package** already in use → use `GoogleFonts.notoSansBengali()` dynamically when language is Bangla
- Or bundle `NotoSansBengali` TTF locally in `assets/fonts/`

**Plan:** Use `google_fonts` with the already-installed package. In `main.dart`, wrap `MaterialApp` with a `Consumer<LanguageProvider>` that applies `GoogleFonts.notoSansBengaliTextTheme()` when Bangla is selected.

> [!IMPORTANT]
> This is the **most critical technical step**. Without Bangla font support, all Bangla characters will render as boxes. The `google_fonts` package already handles this seamlessly.

---

## How to Use Strings in Code

**Before:**
```dart
const Text('Save Settings')
```

**After:**
```dart
Text(context.read<LanguageProvider>().strings.saveSettings)
```

For widgets that need to rebuild when language changes, use `context.watch` instead:
```dart
Text(context.watch<LanguageProvider>().strings.saveSettings)
```

---

## Verification Plan

### Build Verification
```
flutter analyze
flutter build apk --debug
```
Expected: zero analyzer errors, clean build.

### Manual Verification (Step-by-Step)

**Test 1: Language Toggle**
1. Run app → go to Admin Panel → Settings
2. Find the **Language** section at the bottom
3. Tap **বাংলা** — the entire UI should switch to Bangla immediately
4. Tap **English** — the entire UI should switch back to English
5. Kill and reopen app — verify the language choice **persists**

**Test 2: Bangla Rendering (No boxes)**
1. Set language to বাংলা
2. Navigate through: Home → Admin Dashboard → Settings → Returns → Product List
3. Verify all labels render as proper Bangla glyphs (not ☐☐☐)

**Test 3: English Completeness**
1. Set language to English
2. Navigate all screens — confirm every label is in English (no missing/empty strings)

**Test 4: Bangla Completeness**
1. Set language to বাংলা
2. Navigate all screens — confirm no label falls back to English or shows as empty

**Test 5: Dynamic Strings Work**
1. In Bangla mode, scan a barcode that doesn't exist
2. Snackbar should show Bangla message: "বারকোডের পণ্য পাওয়া যায়নি..."
3. Add an item to cart — snackbar should show Bangla confirmation

**Test 6: Numbers and Amounts Not Translated**
1. Confirm that numeric values (prices, stock counts) and user-entered data (medicine names) remain unchanged in both languages
