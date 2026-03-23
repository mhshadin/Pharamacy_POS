# Medicine Types Integration (Execution Plan)

This plan details the implementation of medicine types (Tablet, Syrup, etc.) across the Pharmacy POS system, enabling dynamic management in Settings and post-scan selection in the Cart.

**Project Type**: MOBILE (Flutter)
**Primary Agent**: `mobile-developer`
**Status**: Ready for Implementation

## Success Criteria
- [ ] Database Migration (v10) adds `medType` to `products` and `sales`.
- [ ] `SettingsScreen` allows Adding/Removing custom medicine types.
- [ ] `StockInScreen` defaults to "Tablet" in a premium selection dropdown.
- [ ] `ManualAddScreen` (POS) features horizontal filter chips and iconic badges.
- [ ] `PosCartItemCard` includes a dropdown to change type post-scan.
- [ ] Exported reports (CSV/Excel) include the `MedType` column.

## Tech Stack
- **Flutter / Dart**
- **SQLite** (via `sqflite`)
- **Provider** (State Management)
- **SharedPreferences** (Settings Persistence)
- **Lucide Icons** (Visuals)

---

## Task Breakdown

### Phase 1: Foundation (P0)
**Agent**: `mobile-developer` | **Skills**: `clean-code`, `database-design`

1.  **[T1.1] Update Models**: Add `medType` to `Product`, `CartItem`, and `SaleRecord`.
    *   **INPUT**: `lib/models/*.dart`
    *   **OUTPUT**: Models with `medType` fields and updated serialization (`toMap`, `fromMap`).
    *   **VERIFY**: Fix all compilation errors in related screens.
2.  **[T1.2] DB Migration**: Update `DatabaseHelper` to version 10.
    *   **INPUT**: `lib/services/database_helper.dart`
    *   **OUTPUT**: `_onUpgrade` logic to `ALTER TABLE` for `products` and `sales`.
    *   **VERIFY**: `adb shell sqlite3` check or successful app launch.
3.  **[T1.3] AdminProvider Logic**: Implement management methods and defaults.
    *   **INPUT**: `lib/providers/admin_provider.dart`
    *   **OUTPUT**: `medicineTypes` list persisted via `SharedPreferences`.
    *   **VERIFY**: Unit test or manual check of list persistence.

### Phase 2: Admin UI & Entry (P1)
**Agent**: `mobile-developer` | **Skills**: `frontend-design`

1.  **[T2.1] Settings CRUD**: Implement the "Medicine Types" management section.
    *   **INPUT**: `lib/screens/admin/settings_screen.dart`
    *   **OUTPUT**: List of chips with add/delete interaction.
    *   **VERIFY**: Add "Spray", verify it persists.
2.  **[T2.2] Entry Forms**: Update `StockInScreen` and `EditProductScreen`.
    *   **INPUT**: `lib/screens/admin/*_screen.dart`
    *   **OUTPUT**: Dropdown selectors with "Tablet" default.
    *   **VERIFY**: Dropdown shows all Types from `AdminProvider`.
3.  **[T2.3] Bulk Import**: Update templates and parser.
    *   **INPUT**: `lib/screens/admin/Bulk_import_screen.dart`
    *   **OUTPUT**: Recognizes "MedType" column; updated downloadable CSV/Excel.
    *   **VERIFY**: Import sample file, verify `medType` is populated in DB.

### Phase 3: POS Experience (P2)
**Agent**: `mobile-developer` | **Skills**: `mobile-design`

1.  **[T3.1] Filtering Bar**: Add horizontal `ChoiceChip`s to `ManualAddScreen`.
    *   **INPUT**: `lib/screens/manual_add_screen.dart`
    *   **OUTPUT**: Interactive filter bar that clears on barcode scan.
    *   **VERIFY**: Tap "Capsule" -> verify grid only shows capsules.
2.  **[T3.2] Cart Integration**: Implement post-scan adjustment dropdown.
    *   **INPUT**: `lib/widgets/home/pos_cart_item_card.dart`
    *   **OUTPUT**: Small dropdown in cart item; updates `CartItem.medType`.
    *   **VERIFY**: Scan item -> Change type in cart -> Verify total price remains unchanged.

### Phase 4: Reports (P3)
**Agent**: `mobile-developer` | **Skills**: `clean-code`

1.  **[T4.1] Export Metadata**: Update `ExportService`.
    *   **INPUT**: `lib/services/export_service.dart`
    *   **OUTPUT**: `MedType` column in generated spreadsheets.
    *   **VERIFY**: Export product report and check headers.

---

## ✅ PHASE X: VERIFICATION CHECKLIST
- [ ] No purple/violet hex codes used.
- [ ] Socratic Gate respected.
- [ ] Database migration preserves existing data.
- [ ] UI Audit: Badges are consistently positioned across all 10+ lists.
