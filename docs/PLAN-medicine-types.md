# Project Plan: Medicine Types Integration

This plan details the implementation of medicine types (e.g., Tablet, Syrup, Injection) across the entire Pharmacy POS system, including Admin management and POS-side search/UI.

## Phase 1: Foundation (Enablers)

### 1.1 Product Model Update
- **File**: `lib/models/product.dart`
- **Change**: Add `final String? medType;` field.
- **Reason**: Core data field for filtering and display.

### 1.2 Database Schema Migration
- **File**: `lib/services/database_helper.dart`
- **Action**: Increment DB version to `10`.
- **Migration**: Add `ALTER TABLE products ADD COLUMN medType TEXT;` in `_onUpgrade`.
- **Consistency**: Update `_onCreate` and seed data methods.

### 1.3 AdminProvider Logic
- **File**: `lib/providers/admin_provider.dart`
- **Features**:
  - `List<String> get medicineTypes`.
  - Methods to add/remove types from settings persistence (SharedPreferences).
  - Initial default list of 12 types.

### 1.4 Cart & Sale Models
- **Files**: `lib/models/cart_item.dart`, `lib/models/sale_record.dart`
- **Action**: Add `medType` field to both to support per-transaction type selection and history.

---

## Phase 2: Admin UI & Settings

### 2.1 Settings Management
- **File**: `lib/screens/admin/settings_screen.dart`
- **UI**: Add a new section for "Medicine Types".
- **Interaction**: A list of chips/tags with an 'add' button and 'delete' icon on each.

### 2.2 Stock In Integration
- **File**: `lib/screens/admin/stock_in_screen.dart`
- **UI**: Add a `DropdownButtonFormField` for medicine type.
- **Logic**: Default selection set to 'Tablet'.

### 2.3 Product List & Filtering
- **File**: `lib/screens/admin/product_list_screen.dart`
- **Display**: Show the iconic type badge on each product card.
- **Filtering**: Add a `medType` filter sheet (similar to Company/Generic filters).

### 2.4 Product Editing
- **File**: `lib/screens/admin/edit_product_screen.dart`
- **UI**: Add a `DropdownButtonFormField` for medicine type.
- **Logic**: Populate from `AdminProvider.medicineTypes`.

### 2.5 Bulk Import & Templates
- **File**: `lib/screens/admin/bulk_import_screen.dart`
- **UI**: Update `_expectedHeaders` and `_sampleRow` to include "MedType".
- **Logic**: Ensure parsing logic maps the CSV/Excel column to the `medType` field.
- **Templates**: Ensure downloaded example files include the "MedType" column.

---

## Phase 3: POS Layer & UI/UX

### 3.1 POS Provider Extensions
- **File**: `lib/providers/pos_provider.dart`
- **Search**: Update `filteredProducts` to include `medType` in the sub-string match logic.
- **Filter**: Add `_selectedMedType` state and behavior.
- **Auto-Clear**: `handleBarcodeScan` must reset `_selectedMedType` to `null`.

### 3.2 Manual Add Premium UI
- **File**: `lib/screens/manual_add_screen.dart`
- **Filter Bar**: Scrollable horizontal list of `ChoiceChip`s for types.
- **Product Card**:
  - Add an iconic "Type Badge" (e.g., Pill icon + "Tablet" text).
  - Use Blue-themed primary accent (#3B82F6) for these elements.

### 3.3 Cart Display & Selection
- **File**: `lib/widgets/home/pos_cart_item_card.dart`
- **UI**: Add a `DropdownButton` or picker for medicine type.
- **Logic**: Allows changing the type post-scan (e.g., if a user scans a barcode and it defaults to 'Tablet', they can quickly switch to 'Syrup').

---

## Phase 4: Utilities & Polish

### 4.1 Icon Mapping
- **File**: `lib/utils/med_type_icons.dart`
- **Utility**: `IconData getMedTypeIcon(String? type)` mapping medicine types to LucideIcons.

### 4.2 Export Service Update
- **File**: `lib/services/export_service.dart`
- **Report**: Add "Type" column to product CSV/PDF exports.

## Phase 5: Verification

1.  **DB Migration**: Verify app starts and existing products are preserved.
2.  **Settings**: Add a new type (e.g., "Lotion") -> Verify it appears in the dropdowns.
3.  **Stock In**: Add a product as 'Syrup' -> Verify it saves.
4.  **Admin List**: Verify 'Syrup' filter works and badge shows.
5.  **Edit**: Change 'Syrup' to 'Tablet' -> Verify it updates.
6.  **POS Filter**:
    - Tap 'Tablet' chip -> verify only tablets show.
    - Scan a barcode -> verify 'Tablet' chip clears and product is added.
7.  **Bulk Import**: Import the updated sample file -> Verify `medType` is populated.

---
**Agent Assignments**:
- `@backend-specialist`: Phase 1 & 1.3
- `@frontend-specialist`: Phase 2 & Phase 3
- `@orchestrator`: Final Verification
