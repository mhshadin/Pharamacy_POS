# Home Screen UI (PharmaPOS) — Design & Behavior

This document describes the **redesigned Pharmacy POS home screen**: layout, UX behavior, states, and how it maps to the Flutter implementation.

## Goals

- **Cart-first workflow**: cashier eyes stay on cart and total.
- **Fewer taps**: scan/voice/OCR/manual actions are reachable immediately.
- **Readable + calm**: high contrast, larger touch targets, minimal clutter.
- **Works on phone + large screens**: responsive layout (single column vs split view).

## Source of truth (code)

- **Main screen**: `lib/screens/home_screen.dart`
- **Scanner module**: `lib/widgets/home/pos_scanner_section.dart`
- **Quick actions bar**: `lib/widgets/home/pos_quick_actions.dart`
- **Checkout footer**: `lib/widgets/home/pos_checkout_footer.dart`
- **Colors**: `lib/utils/colors.dart`

## High-level layout (new)

### Phone layout (single column)

```mermaid
flowchart TD
  AppBar[\"GradientAppBar: PharmaPOS + Search + Alerts + Drawer\"]
  Search[\"ExpandableSearchBar: inline product search + suggestions dropdown\"]
  Quick[\"QuickActionsRow: Scan/Hide | Manual | OCR | Voice\"]
  Scanner[\"CollapsibleScannerCard: expanded 140px OR collapsed 48px\"]
  Voice[\"VoiceBar: only when voice active\"]
  Cart[\"CartList: expands to fill remaining height\"]
  Footer[\"CheckoutFooter: items chip + clear + total + gradient checkout CTA\"]

  AppBar --> Search --> Quick --> Scanner --> Voice --> Cart --> Footer
```

### Large layout (desktop/tablet, width > 900)

```mermaid
flowchart LR
  subgraph leftCol [\"LeftColumn (fixed width)\"]
    SearchL[\"SearchBar\"]
    QuickL[\"QuickActions\"]
    VoiceL[\"VoiceBar\"]
    ScannerL[\"ScannerCard\"]
  end

  subgraph rightCol [\"RightColumn\"]
    CartR[\"CartList\"]
    FooterR[\"CheckoutFooter\"]
  end

  leftCol --> rightCol
```

## Top bar (AppBar)

**What it is**

- A standard `AppBar` with a **gradient background** (`primary → primaryDark`).
- Left: hamburger menu opens `PosDrawer`.
- Right: search toggle + alerts button (placeholder handler).

**Why**

- Establishes a modern brand header and keeps navigation predictable.

**Implementation**

See the AppBar definition in:

```686:718:c:/Users/darkm/Desktop/pharmacy/pharmacy_pos/lib/screens/home_screen.dart
return Scaffold(
  // ...
  appBar: AppBar(
    toolbarHeight: 64,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    // ...
  ),
);
```

## Inline search (expandable)

### Behavior

- Toggled by the search icon in the AppBar.
- When open:
  - Typing filters products (`name` or `generic`) and shows a **suggestions dropdown** (top 6 matches).
  - Tap a suggestion: adds **1 pc** to cart and closes the dropdown.
  - Submit (`enter`) or tap the `+` suffix: adds the **first match** (existing behavior).
- When focus leaves the search field: the suggestions overlay closes automatically.

### Why it’s designed this way

- Cashiers often know the name/generic but don’t want to navigate away to another screen.
- Suggestions prevent “silent first match” mistakes and reduce rework.

### Implementation notes

- Uses an `OverlayEntry` anchored to the search field via `LayerLink` + `CompositedTransformTarget/Follower`.
- The overlay is created only when needed and removed on close/focus loss.

Key state/fields:

```50:65:c:/Users/darkm/Desktop/pharmacy/pharmacy_pos/lib/screens/home_screen.dart
bool _isSearchVisible = false;
final TextEditingController _searchController = TextEditingController();
final FocusNode _searchFocus = FocusNode();

final LayerLink _searchLayerLink = LayerLink();
final GlobalKey _searchFieldKey = GlobalKey();
OverlayEntry? _searchOverlay;
List<Product> _searchSuggestions = [];
```

## Quick Action Bar (Scan / Manual / OCR / Voice)

**What it is**

A single-row set of large “pill buttons” designed for fast tapping:

- **Scan/Hide**: expands/collapses the scanner card
- **Manual**: opens `ManualAddScreen`
- **OCR**: starts OCR capture flow
- **Voice**: toggles voice search mode

**Implementation**

`PosQuickActions`:

```5:68:c:/Users/darkm/Desktop/pharmacy/pharmacy_pos/lib/widgets/home/pos_quick_actions.dart
class PosQuickActions extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          // Scan/Hide | Manual | OCR | Voice
        ],
      ),
    );
  }
}
```

## Scanner card (collapsible)

### States

1. **Expanded** (default)
   - Camera preview (mobile only)
   - Scan line animation
   - Tap-to-pause/resume camera
   - Collapse chevron

2. **Collapsed**
   - 48px status bar (“Scanner active/paused”)
   - Expand chevron

### Implementation

`PosScannerSection` is controlled by `isExpanded` and `onToggleExpanded`.

```31:74:c:/Users/darkm/Desktop/pharmacy/pharmacy_pos/lib/widgets/home/pos_scanner_section.dart
if (!isExpanded) {
  return Padding(
    child: Container(
      height: 48,
      // ...
    ),
  );
}
```

### Barcode scan handling

- Home screen prevents duplicate handling while a scan is processing.
- On drawer navigation, camera is stopped/restarted appropriately.

## Voice search (overlay bar)

### Behavior

- Toggled via Quick Actions “Voice”.
- Shows a blurred overlay bar with a text field.
- Speech results populate the field live.
- Final speech triggers fuzzy matching; best match (if found) is added to cart.

### UX notes

- “No match” path encourages editing + search instead of failing silently.
- The bar is intentionally visually distinct so cashiers know they’re in a special mode.

## Cart list (cart-first)

### Behavior

When cart is empty:
- Friendly empty state + “Add First Item” CTA to Manual Add.

When cart has items:
- Items render as cards.
- Swipe-to-delete is supported with undo (implemented in the cart list widget).

## Checkout footer (sticky)

### What it shows

- Item count pill
- Clear button (icon)
- Total payable with currency symbol
- Primary CTA: large gradient checkout button (`primary → accent`)

### Implementation

```27:155:c:/Users/darkm/Desktop/pharmacy/pharmacy_pos/lib/widgets/home/pos_checkout_footer.dart
return Container(
  decoration: const BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  child: Column(
    children: [
      // items chip + total
      // gradient CTA
    ],
  ),
);
```

## Responsiveness rules

- **Phone**: single column with `Expanded(child: cartList)` so cart consumes the available height.
- **Large screens (> 900px)**:
  - Left fixed-width column (scanner area)
  - Right main column (cart + checkout footer)

## Key UX flows

```mermaid
flowchart TD
  Start[\"Home\"] --> Scan[\"Scan barcode\"]
  Start --> Manual[\"Manual add\"] 
  Start --> OCR[\"OCR scan\"] 
  Start --> Voice[\"Voice add\"] 
  Start --> Search[\"Type search + pick suggestion\"]

  Scan --> Cart[\"Item added to cart\"]
  Manual --> Cart
  OCR --> Review[\"OCR Results screen\"] --> Cart
  Voice --> Cart
  Search --> Cart

  Cart --> Checkout[\"Checkout CTA\"] --> Complete[\"Sale complete + invoice snackbar\"]
```

## Accessibility & usability notes

- **Touch targets**: quick actions are ~48px height; footer CTA is large and full width.
- **Contrast**: primary gradients and card borders keep controls readable on light surfaces.
- **Progress feedback**:
  - scanner processing overlay
  - OCR “Reading strip…” loading dialog
  - snackbars for success/error

## Known follow-ups / polish ideas (optional)

- Add real alerts behavior for the bell icon (low-stock / expiring soon summary).
- Add keyboard navigation hints for desktop (enter to checkout, etc.).
- Add haptic feedback for successful scan (mobile only).

