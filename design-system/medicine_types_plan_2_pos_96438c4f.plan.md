---
name: Medicine Types Plan 2 POS
overview: Extend POS-side search and filtering for `medType` (and `companyName`), add type chips and badges on the Manual Add product list, show type on cart lines, and optionally centralize list filtering in `POSProvider` so `filteredProducts` / `filteredCart` stay consistent. Explicitly excludes admin screens (Plan 3).
todos:
  - id: p2-pos-provider
    content: "POSProvider: null-safe search on medType + companyName; optional _selectedMedType + setters; filteredProducts/filteredCart apply both"
    status: pending
  - id: p2-manual-add
    content: "manual_add_screen: wire TextField + chips to POSProvider; type badge on cards; use filteredProducts"
    status: pending
  - id: p2-cart-card
    content: "pos_cart_item_card: show medType with generic when non-null"
    status: pending
  - id: p2-optional-cart-search
    content: "Optional: home_screen search field calling setSearchQuery for filteredCart"
    status: pending
isProject: false
---

# Plan 2 — Medicine types (POS layer)

**Depends on:** [Plan 1 — Foundation](c:\Users\darkm.cursor\plans\medicine_types_plan_1_foundation.md) (`Product.medType`, DB migration, `AdminProvider.medicineTypes`).

**Before Plan 3:** [Plan 3 — Admin UI](c:\Users\darkm.cursor\plans\medicine_types_plan_3_admin_ui.md) covers product list, low stock, expiring, returns, dashboard — do **not** implement those here.

---

## Codebase alignment (important)

- The **POS product search list and cards** are implemented in `[lib/screens/manual_add_screen.dart](lib/screens/manual_add_screen.dart)` (opened via Manual from `[lib/widgets/home/pos_scanner_section.dart](lib/widgets/home/pos_scanner_section.dart)`), not on `[lib/screens/home_screen.dart](lib/screens/home_screen.dart)`. The existing Plan 2 stub pointed at `home_screen` + `pos_scanner_section`; **chips and result badges belong on Manual Add** unless you later add a product grid to the home layout.
- `[lib/providers/pos_provider.dart](lib/providers/pos_provider.dart)` already defines `filteredProducts`, `filteredCart`, and `setSearchQuery`, but `**setSearchQuery` is not called from any screen today** — only `[lib/widgets/home/pos_cart_list.dart](lib/widgets/home/pos_cart_list.dart)` reads `filteredCart`. Plan 2 should either wire search from UI or refactor Manual Add to use the provider so this logic is not dead code.

---

## 1. `[lib/providers/pos_provider.dart](lib/providers/pos_provider.dart)`

**Search predicates (null-safe):**

- In `filteredProducts` and `filteredCart`, extend the `where` so the query matches (case-insensitive `contains`):
  - `name`, `generic` (existing)
  - `medType` — only if non-null: `product.medType!.toLowerCase().contains(lowerQuery)`
  - `companyName` — same pattern for `item.product.companyName`

**Optional type filter (recommended for one pipeline):**

- Add `String? _selectedMedType` (null = All) with `setSelectedMedType(String? value)` and `notifyListeners()`.
- Apply both **text** and **type** filters: a product passes if it matches the search query (as above) **and** (`_selectedMedType == null` or `product.medType == _selectedMedType`).
- Expose a single list for Manual Add, e.g. keep using `filteredProducts` for the full product list with both filters applied.

**Barcode:** `[handleBarcodeScan](lib/providers/pos_provider.dart)` resolves by DB barcode only — **do not** change; chips/search do not affect scan behavior.

---

## 2. `[lib/screens/manual_add_screen.dart](lib/screens/manual_add_screen.dart)`

**Wire to provider (if you add `_selectedMedType` + extended search):**

- Replace the local `products` list built from `posProvider.products.where(...)` (see ~lines 226–231) with `**posProvider.filteredProducts`** (or equivalent).
- On the search `TextField`, `onChanged`/`onSubmitted` → `posProvider.setSearchQuery(...)`.
- Horizontal scroll: `**All**` chip + chips from `context.watch<AdminProvider>().medicineTypes` (same strings as Plan 1). Tapping a chip calls `setSelectedMedType` (null for All).

**UI:**

- **Type badge** on each product card when `product.medType != null` (compact `Chip` / `Container` next to the title row — match existing `[AppColors](lib/utils/colors.dart)` and typography in that file).

**Voice:** `[ProductMatcher](lib/utils/product_matcher.dart)` drives voice/manual resolution — only touch if you need spoken “syrup” to rank better; **not required** unless you verify a failure.

---

## 3. `[lib/widgets/home/pos_cart_item_card.dart](lib/widgets/home/pos_cart_item_card.dart)`

- Under or after the generic line (~lines 67–74), when `item.product.medType != null`, show a short line or inline suffix, e.g. `**Analgesic • Tablet`** (generic • medType), matching the plan’s intent.

---

## 4. Optional: cart text search on home

If you want **“No items match search”** in `[pos_cart_list.dart](lib/widgets/home/pos_cart_list.dart)` to be reachable: add a minimal search field (e.g. above the cart list in `[home_screen.dart](lib/screens/home_screen.dart)`) that calls `posProvider.setSearchQuery`. **Same** `medType`/`companyName` rules as in `filteredCart` then apply. Skip this if you only care about Manual Add + cart lines.

---

## Verification

- Typing `syrup` in **Manual Add** search returns products whose `medType` contains “syrup”, and still matches name/generic.
- Selecting a type chip narrows the list; combined with text search, **both** apply.
- Type badge appears on Manual Add cards when `medType` is set.
- Cart line shows generic + type when `medType` is non-null.
- Barcode scan still adds the product regardless of chip/search state.

---

## Scope boundaries


| In Plan 2                                         | Plan 3 (later)                                                    |
| ------------------------------------------------- | ----------------------------------------------------------------- |
| POS Manual Add + cart card; `POSProvider` filters | Admin product list, low stock, expiring, returns, dashboard icons |


