# PLAN: Remaining Screen Localization

**Variant:** `PLAN-remaining-l10n.md`  
**Scope:** Localize the 5 remaining screens identified in the audit into the existing `LanguageProvider` + `AppStrings` system.  
**Languages:** English (EN) + Bangla (BN)

---

## Overview

After completing localization for 15 of 22 screens, the following remain. This plan details the exact strings, new keys, and file changes needed for each screen.

---

## Phase 1 – High Priority (Daily-Use Admin Screens)

### Screen 1: `expiring_soon_screen.dart`

**File:** `lib/screens/admin/expiring_soon_screen.dart`

#### Hardcoded Strings to Replace

| Location | Hardcoded String | New AppStrings Key |
|---|---|---|
| AppBar title | `'Expiring Soon Alerts'` | `expiringSoonTitle` ✅ exists |
| Empty state title | `'No products expiring soon!'` | `noExpiringSoon` ✅ exists |
| Empty state subtitle | `'All products have more than ${admin.expiringSoonDays} days until expiry.'` | New: `allProductsValidForDays(int days)` |
| Filter chip "All" | `'All'` | `filterAll` (new) |
| Filter chip "Critical" | `'Critical'` | `filterCritical` (new) |
| Filter chip "Warning" | `'Warning'` | `filterWarning` (new) |
| Filter chip "Notice" | `'Notice'` | `filterNotice` (new) |
| Company filter | `'Filter by Company'` | `filterByCompany` ✅ exists |
| Company filter "All Companies" | `'All Companies'` | `allCompanies` (new) |
| Company filter "X Companies" | `'${n} Companies'` | `nCompanies(int n)` (new) |
| Clear All button | `'Clear All'` | `clearAll` ✅ exists |
| Apply button | `'Apply'` | `applyBtn` ✅ exists |
| Result count | `'${n} product(s)'` | `productsCount(int n)` (new) |
| Export button | `'Export'` | `exportOrderList` ✅ exists |
| Sort tooltip | `'Sort'` | `sortBtn` ✅ exists |
| Sort option "Soonest First" | `'Soonest First'` | `sortSoonestFirst` (new) |
| Sort option "Latest First" | `'Latest First'` | `sortLatestFirst` (new) |
| Sort option "A → Z" | `'A → Z'` | `sortNameAZ` ✅ exists |
| Sort option "Z → A" | `'Z → A'` | New: `sortNameZA` (new) |
| Bottom sheet "Export Order List" | `'Export Order List'` | `exportOrderList` ✅ exists |
| Bottom sheet "Export to PDF" | `'Export to PDF'` | `exportPdf` ✅ exists |
| Bottom sheet "Export to CSV" | `'Export to CSV'` | `exportCsv` ✅ exists |
| Order qty dialog title | `'Set Order Quantities'` | `setOrderQuantities` (new) |
| Order qty dialog subtitle | `'Enter how many boxes to order...'` | `enterBoxesToOrder` (new) |
| Order qty field label | `'Boxes'` | `boxes` ✅ exists |
| Order qty "Cancel" | `'Cancel'` | `cancel` ✅ exists |
| Order qty "Next" | `'Next'` | New: `next` (new) |
| Snackbar success | `'Order list exported successfully!'` | `exportSuccess` ✅ exists |
| Snackbar fail | `'Failed to export order list.'` | `exportFailed` ✅ exists |
| Snackbar "Open" action | `'Open'` | `open` ✅ exists |

**New Keys Needed:** `allProductsValidForDays(int)`, `filterAll`, `filterCritical`, `filterWarning`, `filterNotice`, `allCompanies`, `nCompanies(int)`, `productsCount(int)`, `sortSoonestFirst`, `sortLatestFirst`, `sortNameZA`, `setOrderQuantities`, `enterBoxesToOrder`, `next`

---

### Screen 2: `low_stock_screen.dart`

**File:** `lib/screens/admin/low_stock_screen.dart`

#### Hardcoded Strings to Replace

| Location | Hardcoded String | New AppStrings Key |
|---|---|---|
| AppBar title | `'Low Stock Alerts'` | `lowStockTitle` ✅ exists |
| Empty state title | `'All products well stocked!'` | `allStockGood` ✅ exists |
| Empty state subtitle | `'No products below minimum stock level.'` | `noLowStockExpiring` ✅ exists |
| Search hint | `'Search name, generic, company…'` | `searchHint` ✅ exists |
| Filter chip "All" | `'All'` | `filterAll` (shared with above) |
| Filter chip "Out of Stock" | `'Out of Stock'` | `filterOutOfStock` (new) |
| Filter chip "Low Stock" | `'Low Stock'` | `lowStockBadge` ✅ exists |
| Company filter texts (same as above) | — | Shared keys |
| Sort option "Most Urgent" | `'Most Urgent'` | `sortMostUrgent` (new) |
| Sort option "Biggest Deficit" | `'Biggest Deficit'` | `sortBiggestDeficit` (new) |
| Sort option "A → Z" | `'A → Z'` | `sortNameAZ` ✅ exists |
| Sort option "Z → A" | `'Z → A'` | `sortNameZA` (shared) |
| Export + result count | same pattern as above | shared keys |
| Order qty dialog title | `'Confirm Order Quantities'` | `confirmOrderQuantities` (new) |
| Order qty dialog "Deficit: X strips" | `'Deficit: ${n} strips'` | `deficitUnits(int n, String unit)` (new) |
| Empty filter message | `'No products match your filters.'` | `noProductsMatchCriteria` ✅ exists |
| "Clear Filters" | `'Clear Filters'` | `clearAllFilters` ✅ exists |
| Snackbars | same as above | shared keys |

**New Keys Needed:** `filterOutOfStock`, `sortMostUrgent`, `sortBiggestDeficit`, `confirmOrderQuantities`, `deficitUnits(int, String)`

---

## Phase 2 – Medium Priority

### Screen 3: `manual_add_screen.dart`

**File:** `lib/screens/manual_add_screen.dart`

Already imports and uses `LanguageProvider` for unit labels. Only small gaps remain.

#### Hardcoded Strings to Replace

| Location | Hardcoded String | New AppStrings Key |
|---|---|---|
| AppBar title | `'MANUAL ADD'` | New: `manualAddTitle` |
| Empty state | `'No products found matching search.'` | `noMatchVoice` ✅ (close enough) or new `noProductsFound` ✅ exists |
| Voice snackbar success | `'Added ${name} (1 pc) to cart'` | `addedToCart` ✅ exists |
| Voice snackbar no match | `'No close match found. Please edit the name.'` | `noMatchVoice` ✅ exists |
| Edit qty dialog title | `'Set ${typeLabel} Quantity:\n${name}'` | New: `setQuantityFor(String type, String name)` |
| Edit qty hint | `'Enter amount...'` | New: `enterAmount` |
| Edit qty "Cancel" | `'Cancel'` | `cancelBtn` ✅ exists |
| Edit qty "Save" | `'Save'` | `saveChanges` ✅ exists |
| Voice error snackbar | `'Voice error: $error'` | `voiceError(String)` ✅ exists |

**New Keys Needed:** `manualAddTitle`, `setQuantityFor(String, String)`, `enterAmount`

---

## Phase 3 – Low Priority

### Screen 4: `ocr_scan_result_screen.dart`

**File:** `lib/screens/ocr_scan_result_screen.dart`

No `LanguageProvider` integration yet. Needs full integration.

#### Hardcoded Strings to Replace

| Location | Hardcoded String | New AppStrings Key |
|---|---|---|
| AppBar title | `'Review Scan Results'` | `ocrScanResult` ✅ exists |
| Image preview "Scanned Image" | `'Scanned Image'` | New: `scannedImage` |
| Detected count | `'${n} item(s) detected'` | New: `itemsDetected(int n)` |
| Retake button | `'Retake'` | New: `retake` |
| Card label "SCANNED TEXT" | `'SCANNED TEXT'` | New: `scannedText` |
| Match badge "% match" | `'$n% match'` | New: `matchPercent(int n)` |
| Exact match | `'EXACT MATCH FOUND'` | New: `exactMatchFound` |
| Partial match | `'MULTIPLE MATCHES — PLEASE SELECT:'` | New: `multipleMatchesSelect` |
| Dropdown hint | `'— Select Correct Product —'` | New: `selectCorrectProduct` |
| Status "ACCEPTED" | `'ACCEPTED'` | New: `statusAccepted` |
| Status "REJECTED" | `'REJECTED'` | New: `statusRejected` |
| Status "PENDING" | `'PENDING'` | New: `statusPending` |
| Action "Undo Reject" | `'Undo Reject'` | New: `undoReject` |
| Action "Reject" | `'Reject'` | New: `reject` |
| Action "Accept" | `'Accept'` | New: `accept` |
| Snackbar "Select a product..." | `'Select a product from the dropdown first.'` | New: `selectProductFirst` |
| Snackbar "No medicine detected" | `'No medicine names detected. Try again.'` | `noMedicineDetected` ✅ exists |
| Snackbar OCR error | `'Error: ${e}'` | `ocrError(String)` ✅ exists |
| Snackbar "X product(s) added" | `'$n product(s) added to cart.'` | New: `productsAddedToCart(int n)` |
| Empty state title | `'No matches found'` | New: `noMatchesFound` |
| Empty state subtitle | `'Try retaking the photo...'` | New: `tryRetakingPhoto` |
| Bottom bar "Selected for Import:" | `'Selected for Import:'` | `confirmedItems` ✅ exists |
| Bottom bar "Commit Valid Items" | `'Commit Valid Items'` | New: `commitValidItems` |
| Bottom bar "Resolve Selections First" | `'Resolve Selections First'` | New: `resolveSelectionsFirst` |

**New Keys Needed:** `scannedImage`, `itemsDetected(int)`, `retake`, `scannedText`, `matchPercent(int)`, `exactMatchFound`, `multipleMatchesSelect`, `selectCorrectProduct`, `statusAccepted`, `statusRejected`, `statusPending`, `undoReject`, `reject`, `accept`, `selectProductFirst`, `productsAddedToCart(int)`, `noMatchesFound`, `tryRetakingPhoto`, `commitValidItems`, `resolveSelectionsFirst`

---

### Screen 5: `subscription_screen.dart`

**File:** `lib/screens/subscription_screen.dart`

Primarily payment/WebView UI. Several existing keys already exist in `AppStrings`.

#### Hardcoded Strings to Replace

| Location | Hardcoded String | New AppStrings Key |
|---|---|---|
| Screen title | `'Subscription Plans'` | `subscriptionTitle` ✅ exists |
| Subscribe button | `'Subscribe'` | `subscribeBtn` ✅ exists |
| Current plan | `'Current Plan'` | `currentPlan` ✅ exists |
| Expires on | `'Expires on'` | `expiresOn` ✅ exists |
| Trial expired | `'Trial Expired'` | `trialExpired` ✅ exists |
| Renew button | `'Renew'` | `renewBtn` ✅ exists |
| Loading / error snackbars | various | `loading`, `error` keys + `ApiErrorMapper` |

> **Note:** `subscription_screen` relies partly on `ApiErrorMapper.forPlanLoad()` which is not localized. This is acceptable for now — only UI labels need to be migrated.

**New Keys Needed:** Likely none — most keys already exist.

---

## Phase 4 – AppStrings Contract Updates

### Files to Modify

1. **`lib/l10n/app_strings.dart`** — Add all new key declarations listed above
2. **`lib/l10n/app_strings_en.dart`** — Add English implementations
3. **`lib/l10n/app_strings_bn.dart`** — Add Bangla implementations

### New Keys Summary

| Key | Type | EN Default | BN Translation |
|---|---|---|---|
| `allProductsValidForDays(int days)` | Parameterized | `'All products have more than $days days until expiry.'` | `'সব পণ্যের মেয়াদ $days দিনের বেশি বাকি।'` |
| `filterAll` | Getter | `'All'` | `'সব'` |
| `filterCritical` | Getter | `'Critical'` | `'সংকটজনক'` |
| `filterWarning` | Getter | `'Warning'` | `'সতর্কতা'` |
| `filterNotice` | Getter | `'Notice'` | `'বিজ্ঞপ্তি'` |
| `allCompanies` | Getter | `'All Companies'` | `'সব কোম্পানি'` |
| `nCompanies(int n)` | Parameterized | `'$n Companies'` | `'$n টি কোম্পানি'` |
| `productsCount(int n)` | Parameterized | `'$n product${n==1?'':'s'}'` | `'$n টি পণ্য'` |
| `sortSoonestFirst` | Getter | `'Soonest First'` | `'নিকটতম মেয়াদ আগে'` |
| `sortLatestFirst` | Getter | `'Latest First'` | `'দূরতম মেয়াদ আগে'` |
| `sortNameZA` | Getter | `'Z → A'` | `'Z → A'` |
| `setOrderQuantities` | Getter | `'Set Order Quantities'` | `'অর্ডারের পরিমাণ নির্ধারণ করুন'` |
| `enterBoxesToOrder` | Getter | `'Enter how many boxes to order for each product.'` | `'প্রতিটি পণ্যের জন্য কতটি বক্স অর্ডার করবেন লিখুন।'` |
| `next` | Getter | `'Next'` | `'পরবর্তী'` |
| `filterOutOfStock` | Getter | `'Out of Stock'` | `'স্টক শেষ'` |
| `sortMostUrgent` | Getter | `'Most Urgent'` | `'সবচেয়ে জরুরি'` |
| `sortBiggestDeficit` | Getter | `'Biggest Deficit'` | `'সবচেয়ে বেশি ঘাটতি'` |
| `confirmOrderQuantities` | Getter | `'Confirm Order Quantities'` | `'অর্ডারের পরিমাণ নিশ্চিত করুন'` |
| `deficitUnits(int n, String unit)` | Parameterized | `'Deficit: $n $unit'` | `'ঘাটতি: $n $unit'` |
| `manualAddTitle` | Getter | `'Manual Add'` | `'ম্যানুয়াল যোগ'` |
| `setQuantityFor(String type, String name)` | Parameterized | `'Set $type Quantity:\n$name'` | `'$type পরিমাণ নির্ধারণ করুন:\n$name'` |
| `enterAmount` | Getter | `'Enter amount...'` | `'পরিমাণ লিখুন...'` |
| `scannedImage` | Getter | `'Scanned Image'` | `'স্ক্যান করা ছবি'` |
| `itemsDetected(int n)` | Parameterized | `'$n item${n==1?'':'s'} detected'` | `'$n টি আইটেম শনাক্ত হয়েছে'` |
| `retake` | Getter | `'Retake'` | `'আবার তুলুন'` |
| `scannedText` | Getter | `'SCANNED TEXT'` | `'স্ক্যান করা টেক্সট'` |
| `matchPercent(int n)` | Parameterized | `'$n% match'` | `'$n% মিল'` |
| `exactMatchFound` | Getter | `'EXACT MATCH FOUND'` | `'সঠিক মিল পাওয়া গেছে'` |
| `multipleMatchesSelect` | Getter | `'MULTIPLE MATCHES — PLEASE SELECT:'` | `'একাধিক মিল — অনুগ্রহ করে নির্বাচন করুন:'` |
| `selectCorrectProduct` | Getter | `'— Select Correct Product —'` | `'— সঠিক পণ্য নির্বাচন করুন —'` |
| `statusAccepted` | Getter | `'ACCEPTED'` | `'গৃহীত'` |
| `statusRejected` | Getter | `'REJECTED'` | `'প্রত্যাখ্যাত'` |
| `statusPending` | Getter | `'PENDING'` | `'বিচারাধীন'` |
| `undoReject` | Getter | `'Undo Reject'` | `'বাতিল পূর্বাবস্থায় ফেরান'` |
| `reject` | Getter | `'Reject'` | `'প্রত্যাখ্যান করুন'` |
| `accept` | Getter | `'Accept'` | `'গ্রহণ করুন'` |
| `selectProductFirst` | Getter | `'Select a product from the dropdown first.'` | `'অনুগ্রহ করে প্রথমে ড্রপডাউন থেকে একটি পণ্য নির্বাচন করুন।'` |
| `productsAddedToCart(int n)` | Parameterized | `'$n product(s) added to cart.'` | `'$n টি পণ্য কার্টে যোগ করা হয়েছে।'` |
| `noMatchesFound` | Getter | `'No matches found'` | `'কোনো মিল পাওয়া যায়নি'` |
| `tryRetakingPhoto` | Getter | `'Try retaking the photo with better lighting.'` | `'ভালো আলোতে আবার ছবি তুলে দেখুন।'` |
| `commitValidItems` | Getter | `'Commit Valid Items'` | `'বৈধ আইটেম নিশ্চিত করুন'` |
| `resolveSelectionsFirst` | Getter | `'Resolve Selections First'` | `'আগে নির্বাচন নিষ্পত্তি করুন'` |

---

## Implementation Order

```
- [x] Localize remaining 5 screens
  - [x] Update `AppStrings` with new keys
  - [x] Localize `expiring_soon_screen.dart`
  - [x] Localize `low_stock_screen.dart`
  - [x] Localize `manual_add_screen.dart`
  - [x] Localize `ocr_scan_result_screen.dart`
  - [x] Localize `subscription_screen.dart`
- [x] Final regression test and verification
  - [x] Sweep for missed hardcoded strings
  - [x] Run lint checks
  - [x] Final confirmation
Verification:
  8. Hot restart → toggle language in Settings
  9. Verify all 5 screens switch correctly
  10. Check Dart analysis for zero errors
```

---

## Verification Checklist

- [ ] `dart analyze` returns 0 errors
- [ ] Language toggle in Settings updates `expiring_soon_screen` instantly
- [ ] Language toggle updates `low_stock_screen` instantly
- [ ] Language toggle updates `manual_add_screen` voice snackbars
- [ ] `ocr_scan_result_screen` shows Bangla labels when BN is active
- [ ] `subscription_screen` shows Bangla plan labels when BN is active
- [ ] No hardcoded English strings remain in any of the 5 screens
- [ ] All new keys have both EN and BN implementations (no missing concrete getters)
