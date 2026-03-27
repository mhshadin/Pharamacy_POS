import 'app_strings.dart';

class AppStringsEn implements AppStrings {
  // ── Navigation & App Info ──────────────────────────
  @override String get navDashboard => 'Dashboard';
  @override String get navAddProduct => 'Add Product';
  @override String get navReturns => 'Returns';
  @override String get navSalesReport => 'Sales Report';
  @override String get navExpiringSoon => 'Expiring Soon';
  @override String get navLowStock => 'Low Stock';
  @override String get navProductList => 'Product List';
  @override String get navTopProducts => 'Top Products';
  @override String get navSettings => 'Settings';
  @override String get navProfile => 'Profile';
  @override String get navNotifications => 'Notifications';
  @override String get navBackToPos => 'Back to POS';
  @override String get appName => 'Pharmacy POS';
  @override String get posTitle => 'PharmaPOS';
  @override String get adminPortal => 'ADMIN PORTAL';
  @override String get backToPos => 'Back to POS';

  // ── POS / Home Screen ──────────────────────────────
  @override String get saleComplete => 'Sale Complete';
  @override String get clearCart => 'Clear Cart?';
  @override String get clearCartConfirm => 'Are you sure you want to clear the cart?';
  @override String get newSale => 'New Sale';
  @override String get cancelBtn => 'Cancel';
  @override String get yesClr => 'Yes, Clear';
  @override String get addedToCart => 'Added to cart';
  @override String get noMatchVoice => 'No match – edit the name and tap the search icon.';
  @override String get barcodeNotFound => 'Product not found for barcode';
  @override String get readingStrip => 'Reading strip...';
  @override String get noMedicineDetected => 'No medicine names detected. Try again.';
  @override String get successCharged => 'Successfully charged';
  @override String get successfullyCharged => 'Successfully charged';
  @override String get listening => 'Listening...';
  @override String get searchHint => 'Search medicine name or generic...';
  @override String get voiceSearchHint => 'Edit and tap search...';
  @override String get menuTooltip => 'Menu';
  @override String get searchTooltip => 'Search products';
  @override String get closeSearchTooltip => 'Close search';
  @override String get alertsTooltip => 'Alerts';
  @override String get searchBtnTooltip => 'Search';
  @override String get discardBtnTooltip => 'Discard';
  @override String get saleCompleteInvoice => 'Sale Complete! Invoice:';

  // ── Admin Dashboard ────────────────────────────────
  @override String get overview => 'Overview';
  @override String get todaysSales => "Today's Sales";
  @override String get todaySales => "Today's Sales";
  @override String get totalOrders => 'Total Orders';
  @override String get lowStock => 'Low Stock';
  @override String get expiringSoon => 'Expiring Soon';
  @override String get criticalInventory => 'Critical Inventory';
  @override String get allStockGood => 'All stock is good! 🎉';
  @override String get noLowStockExpiring => 'No low stock or expiring items.';
  @override String get recentTransactions => 'Recent Transactions';
  @override String get lowStockBadge => 'Low Stock';
  @override String get expiringSoonBadge => 'Expiring Soon';
  @override String get unknownExpiry => 'Unknown Expiry';
  @override String get expiresPrefix => 'Expires: ';
  @override String lastUpdated(String dateTime) => 'Last Updated: $dateTime';
  @override String get units => 'Units';
  @override String get pcsSuffix => 'pcs';

  // ── Product Management ─────────────────────────────
  @override String get productList => 'Product List';
  @override String get searchProducts => 'Search Products';
  @override String get editBtn => 'Edit';
  @override String get restockBtn => 'Restock';
  @override String get noProductsFound => 'No products found';
  @override String get deleteProduct => 'Delete Product?';
  @override String get deleteProductConfirm => 'Are you sure you want to delete this product?';
  @override String get deleteBtn => 'Delete';
  @override String get productDeleted => 'Product deleted successfully';
  @override String get addProduct => 'Add Product';
  @override String get editProduct => 'Edit Product';
  @override String get productName => 'Product Name';
  @override String get genericName => 'Generic Name';
  @override String get category => 'Category';
  @override String get pricePerPc => 'Price per Pc';
  @override String get pricePerStrip => 'Price per Strip';
  @override String get pcsPerStrip => 'Pcs per Strip';
  @override String get stockBoxes => 'Stock Boxes';
  @override String get pcsPerBox => 'Pcs per Box';
  @override String get minStockLevel => 'Min Stock Level';
  @override String get expiryDate => 'Expiry Date';
  @override String get supplierName => 'Supplier Name';
  @override String get supplierPhone => 'Supplier Phone';
  @override String get saveProduct => 'Save Product';
  @override String get productSaved => 'Product saved successfully';
  @override String get productUpdated => 'Product updated successfully';
  @override String get requiredField => 'Required field';
  @override String get restock => 'Restock';
  @override String get restockTitle => 'Restock Product';
  @override String get boxesToAdd => 'Boxes to add';
  @override String get confirmRestock => 'Confirm Restock';
  @override String get restockSuccess => 'Restock successful';
  @override String get stockStrips => 'strips';
  @override String get stockPcs => 'pieces';
  @override String get pcsRemaining => 'pcs remaining';
  @override String get minStock => 'min';

  // ── Filtering & Sorting ────────────────────────────
  @override String get filterByCompany => 'Filter by Company';
  @override String get filterByGeneric => 'Filter by Generic';
  @override String get filterByType => 'Filter by Type';
  @override String get searchCompanies => 'Search companies...';
  @override String get searchGenerics => 'Search generics...';
  @override String get clearAll => 'Clear All';
  @override String get applyBtn => 'Apply';
  @override String get deleteProducts => 'Delete Products';
  @override String get deleteConfirm => 'Are you sure you want to delete these products?';
  @override String get sortBtn => 'Sort';
  @override String get sortUrgency => 'Urgency (Recommended)';
  @override String get sortExpiry => 'Expiry: Soonest First';
  @override String get sortNameAZ => 'Name: A → Z';
  @override String get sortPriceHighLow => 'Price: High → Low';
  @override String get sortPriceLowHigh => 'Price: Low → High';
  @override String get noCompaniesFound => 'No companies found';
  @override String get noGenericsFound => 'No generics found';
  @override String get selectItems => 'Select Items';
  @override String get cancelSelection => 'Cancel Selection';
  @override String get deleteSelected => 'Delete Selected';
  @override String get sortNewest => 'Newest First';
  @override String get sortOldest => 'Oldest First';
  @override String get sortHighToLow => 'Amount: High to Low';
  @override String get sortLowToHigh => 'Amount: Low to High';

  // ── Settings & Auth ───────────────────────────────
  @override String get signInToStart => 'Sign in to start selling';
  @override String get emailLabel => 'Email';
  @override String get passwordLabel => 'Password';
  @override String get signInBtn => 'Sign in';
  @override String get continueWithGoogle => 'Continue with Google';
  @override String get orCreateAccount => 'Or create an account';
  @override String get createPharmacyAccount => 'Create Pharmacy Account';
  @override String get createAccountBtn => 'Create account';
  @override String get fullNameLabel => 'Your full name';
  @override String get pharmacyNameLabel => 'Pharmacy / business name';
  @override String get passwordMinChars => 'Password (min 8 characters)';
  @override String get confirmPasswordLabel => 'Confirm password';
  @override String get validationEnterEmail => 'Please enter your email';
  @override String get validationValidEmail => 'Please enter a valid email';
  @override String get validationEnterPassword => 'Please enter your password';
  @override String get validationPasswordMin => 'Password must be at least 8 characters';
  @override String get validationEnterName => 'Please enter your name';
  @override String get validationEnterBusiness => 'Please enter your business name';
  @override String get validationConfirmPassword => 'Please confirm your password';
  @override String get validationPasswordsNoMatch => 'Passwords do not match';
  @override String get loginFailed => 'Login failed. Please try again.';
  @override String get registrationFailed => 'Registration failed. Please try again.';
  @override String get googleSignInFailed => 'Google sign-in failed. Please try again.';
  @override String get inventoryAlerts => 'Inventory Alerts';
  @override String get lowStockThreshold => 'Low Stock Threshold (Boxes)';
  @override String get lowStockThresholdHelper => 'Default warning level in boxes. Individual products can override this.';
  @override String get defaultBoxesToOrder => 'Default Boxes to Order';
  @override String get defaultBoxesHelper => 'This is pre-filled when exporting an order list from Low Stock / Expiring Soon.';
  @override String get expiringSoonWindow => 'Expiring Soon Window (Days)';
  @override String get expiringSoonWindowHelper => 'Products expiring within this many days appear in Expiring Soon.';
  @override String get moderateExpiry => 'Moderate Expiry (Days, Amber)';
  @override String get moderateExpiryHelper => 'Amber highlight: expires within this many days but after the critical (red) range.';
  @override String get criticalExpiry => 'Critical Expiry (Days, Red)';
  @override String get criticalExpiryHelper => 'Red highlight: expires within this many days (and expired stock).';
  @override String get defaultExpiryDelay => 'Default Expiry Delay (Months)';
  @override String get defaultExpiryDelayHelper => 'The initial date in the Add Product date picker will be set to this many months from today.';
  @override String get showSupplierInfo => 'Show Supplier Info in Add Product';
  @override String get showSupplierInfoHelper => 'Enable this to enter and track supplier name and phone number during stock in.';
  @override String get saveSettings => 'Save Settings';
  @override String get settingsSaved => 'Settings saved successfully';
  @override String get expiryOrderError => 'Expiry days must be ordered: Critical (red) ≤ Moderate (amber) ≤ Expiring Soon window.';
  @override String get databaseBackup => 'Database Backup';
  @override String get googleDriveIntegration => 'Google Drive Integration';
  @override String get googleDriveDesc => 'Securely backup your database to Google Drive.';
  @override String get notSyncedYet => 'Not synced yet';
  @override String get syncingNow => 'Syncing now...';
  @override String get syncFailed => 'Sync failed';
  @override String get lastSync => 'Last sync';
  @override String get missingDriveScope => 'Missing Drive scope. Please sign out and sign back in.';
  @override String get ensureSignedIn => 'Ensure you are signed in and have internet.';
  @override String get syncNow => 'Sync Now';
  @override String get phoneStorageBackup => 'Phone Storage Backup';
  @override String get offlineBackupImport => 'Offline Backup & Import';
  @override String get offlineBackupDesc => 'Export a backup file to your phone storage or import an existing .db file.';
  @override String get exportNow => 'Export Now';
  @override String get importDb => 'Import DB';
  @override String get exportedSuccess => 'Database exported to phone storage';
  @override String get importDatabase => 'Import Database?';
  @override String get importDatabaseWarning => 'This will REPLACE all your current data. This action cannot be undone.';
  @override String get importReplace => 'Import & Replace';
  @override String get importSuccess => 'Import successful!';
  @override String get importFailed => 'Import failed';
  @override String get medicineCategories => 'Medicine Categories';
  @override String get medicineCategoriesDesc => 'Manage types like Tablet, Syrup, etc.';
  @override String get addNewType => 'Add new type (e.g. Inhaler)';
  @override String get removeCategory => 'Remove Category?';
  @override String get removeCategoryConfirm => 'Are you sure you want to remove';
  @override String get removeCategoryWarning => 'Existing products with this category will keep it until they are edited.';
  @override String get removeBtn => 'Remove';
  @override String get languageSetting => 'Language';
  @override String get languageEnglish => 'English';
  @override String get languageBangla => 'বাংলা';
  @override String get logout => 'Logout';
  @override String get logoutConfirm => 'Are you sure you want to logout?';
  @override String get notifications => 'Notifications';

  // ── Reports & Others ──────────────────────────────
  @override String get returnsTitle => 'Returns';
  @override String get filterReturns => 'Filter Returns';
  @override String get dateRange => 'Date Range';
  @override String get amountRange => 'Amount Range (৳)';
  @override String get timeRange => 'Time Range';
  @override String get anyTime => 'Any time';
  @override String get clearTime => 'Clear Time';
  @override String get returnItems => 'Return Items';
  @override String get confirmReturn => 'Confirm Return';
  @override String get noItemsInvoice => 'No items to load from this invoice.';
  @override String get allItemsReturned => 'All items in this invoice are already returned.';
  @override String get someProductsSkipped => 'Some products were skipped';
  @override String get couldNotFindProducts => 'Could not find product(s)';
  @override String get returnItemsFor => 'Return items for';
  @override String get strips => 'Strips';
  @override String get pcs => 'Pcs';
  @override String get maxReturnable => 'Max returnable';
  @override String get selected => 'Selected';
  @override String get changeBtn => 'Change';
  @override String get salesReport => 'Sales Report';
  @override String get totalRevenue => 'Total Revenue';
  @override String get totalTransactions => 'Total Transactions';
  @override String get topProduct => 'Top Product';
  @override String get noSalesData => 'No sales data for this period';
  @override String get exportPdf => 'Export PDF';
  @override String get exportCsv => 'Export CSV';
  @override String get exportSuccess => 'Report exported successfully';
  @override String get exportFailed => 'Failed to export report';
  @override String get today => 'Today';
  @override String get thisWeek => 'This Week';
  @override String get thisMonth => 'This Month';
  @override String get last3Months => 'Last 3 Months';
  @override String exportError(String error) => 'Error exporting report: $error';
  @override String get reportSaved => 'Report saved successfully!';
  @override String get reportFailed => 'Failed to save the report.';
  @override String get transactionHistory => 'Transaction History';
  @override String recordsCount(int count) => '$count records';
  @override String get orders => 'Orders';
  @override String get itemsSold => 'Items Sold';
  @override String get noTransactionsFound => 'No transactions found';
  @override String get tryAnotherFilter => 'Try a different date range or filter';
  @override String get revenueTrend => 'Revenue Trend';
  @override String get period => 'Period';
  @override String get customRange => 'Custom range';
  @override String get weekly => 'Weekly';
  @override String get monthly => 'Monthly';
  @override String get yearly => 'Yearly';
  @override String get newestFirst => 'Newest First';
  @override String get oldestFirst => 'Oldest First';
  @override String get amountHigh => 'Amount (High)';
  @override String get amountLow => 'Amount (Low)';
  @override String get productAZ => 'Product A-Z';
  @override String get mon => 'Mon'; @override String get tue => 'Tue'; @override String get wed => 'Wed';
  @override String get thu => 'Thu'; @override String get fri => 'Fri'; @override String get sat => 'Sat'; @override String get sun => 'Sun';
  @override String get jan => 'Jan'; @override String get feb => 'Feb'; @override String get mar => 'Mar';
  @override String get apr => 'Apr'; @override String get may => 'May'; @override String get jun => 'Jun';
  @override String get jul => 'Jul'; @override String get aug => 'Aug'; @override String get sep => 'Sep'; @override String get oct => 'Oct'; @override String get nov => 'Nov'; @override String get dec => 'Dec';
  @override String get others => 'Others';
  @override String get expiringSoonTitle => 'Expiring Soon';
  @override String get lowStockTitle => 'Low Stock Products';
  @override String get exportOrderList => 'Export Order List';
  @override String get noExpiringSoon => 'No products expiring soon';
  @override String get noLowStock => 'No products in low stock';
  @override String get remainingPcs => 'remaining pcs';
  @override String get boxesSuffix => 'boxes';
  @override String get stripsSuffix => 'strips';
  @override String get notificationsTitle => 'Notifications';
  @override String get noNotifications => 'No notifications';
  @override String get markAllRead => 'Mark all as read';
  @override String get profileTitle => 'Profile';
  @override String get signOut => 'Sign Out';
  @override String get signOutConfirm => 'Are you sure you want to sign out?';
  @override String get accountInfo => 'Account Information';
  @override String get changePassword => 'Change Password';
  @override String get currentPassword => 'Current Password';
  @override String get newPassword => 'New Password';
  @override String get updatePassword => 'Update Password';
  @override String get passwordUpdated => 'Password updated successfully';
  @override String get subscriptionTitle => 'Subscription';
  @override String get subscribeBtn => 'Subscribe Now';
  @override String get currentPlan => 'Current Plan';
  @override String get expiresOn => 'Expires on';
  @override String get trialExpired => 'Trial Expired';
  @override String get renewBtn => 'Renew Subscription';
  @override String get ocrScanResult => 'OCR Results';
  @override String get addAllToCart => 'Add all to cart';
  @override String get confirmedItems => 'Confirmed Items';
  @override String get generalInfo => 'General Information';
  @override String get packaging => 'Packaging';
  @override String get pricing => 'Pricing';
  @override String get inventory => 'Inventory';
  @override String get expiryBatch => 'Expiry / Batch';
  @override String get supplierInfo => 'Supplier Information';
  @override String get selectExpiryDate => 'Please select an expiry date for trackable stock.';
  @override String get batchNumber => 'Batch Number';
  @override String get barcodeLabel => 'Barcode (optional)';
  @override String get scanBtn => 'Scan';
  @override String get stripsPerBox => 'Strips per Box';
  @override String get failedToSaveProduct => 'Failed to save product. Please try again.';
  @override String get noDate => 'No Date';
  @override String get bulkImport => 'Bulk Import CSV';
  @override String get changeMedType => 'Change Medicine Type';
  @override String get returns => 'Returns';
  @override String get searchBtn => 'Search';
  @override String get searchHelpText => 'Search by Invoice No. or Product Name';
  @override String get noResults => 'No results found';
  @override String get fullyReturned => 'Fully Returned';
  @override String get qtyLabel => 'Qty';
  @override String get retLabel => 'Ret';
  @override String get batchLabel => 'Batch';
  @override String get returnsProcessed => 'Returns processed successfully!';
  @override String get sortBy => 'Sort By';
  @override String get sortAmountHigh => 'Amount: High to Low';
  @override String get sortAmountLow => 'Amount: Low to High';
  @override String get filters => 'Filters';

  // ── Common / Shared ───────────────────────────────
  @override String get loading => 'Loading...';
  @override String get error => 'Error';
  @override String get success => 'Success';
  @override String get tryAgain => 'Try again';
  @override String get toLabel => 'to';
  @override String get close => 'Close';
  @override String get open => 'Open';
  @override String get confirm => 'Confirm';
  @override String get apply => 'Apply';
  @override String get search => 'Search';
  @override String get filter => 'Filter';
  @override String get sort => 'Sort';
  @override String get noResultsFound => 'No results found';
  @override String get boxes => 'Boxes';
  @override String get minAmount => 'Min ৳';
  @override String get maxAmount => 'Max ৳';

  @override String get deselectAll => 'Deselect All';
  @override String get selectAll => 'Select All';
  @override String selectedCount(int count) => '$count Selected';
  @override
  String sortOption(String option) {
    switch (option) {
      case 'Urgency (Recommended)':
        return 'Urgency (Recommended)';
      case 'Expiry: Soonest First':
        return 'Expiry: Soonest First';
      case 'Name: A → Z':
        return 'Name: A → Z';
      case 'Price: High → Low':
        return 'Price: High → Low';
      case 'Price: Low → High':
        return 'Price: Low → High';
      default:
        return option;
    }
  }
  @override String get productListEmpty => 'Your product list is currently empty.';
  @override String get noProductsMatchCriteria => 'No products match your search/filter criteria.';
  @override String get clearAllFilters => 'Clear All Filters';
  @override String get inStock => 'In Stock';
  @override String get pieces => 'Pcs';
  @override String get stripPrice => 'Strip ৳';
  @override String get edit => 'Edit';
  @override String get cancel => 'Cancel';
  @override String get delete => 'Delete';
  @override String deleteProductsConfirmation(int count) => 'Are you sure you want to delete $count products?';

  @override
  String get deleteSelectedTooltip => 'Delete Selected';
  @override String get taka => 'Taka';
  @override String get companyName => 'Company Name';
  @override String get scan => 'Scan';
  @override String get exp => 'Exp';
  @override String get syrupHint => 'e.g. 100 ml per bottle';
  @override String get tube => 'Tube';
  @override String get vial => 'Vial';
  @override String get bottle => 'Bottle';
  @override String get sachet => 'Sachet';
  @override String get inhaler => 'Inhaler';
  @override String get patch => 'Patch';
  @override String get unit => 'Unit';
  @override String get ml => 'ml';
  @override String get grams => 'g';
  @override String get price => 'Price';
  @override String get invoicePrefix => 'Invoice:';
  @override String get onePcSuffix => ' (1 pc)';
  @override String voiceError(String error) => 'Voice error: $error';
  @override String ocrError(String error) => 'OCR error: $error';
  @override String get googleIdTokenError => 'Unable to get Google ID token.';
  @override String get createAccount => 'Create Account';
  @override String get unknownInvoice => 'Unknown Invoice';

  // --- Parameterized ---
  @override
  String productStockDetails(int boxes, int strips, int pcs, int min) =>
      '$boxes boxes • $strips strips • $pcs pcs remaining (min: $min)';

  @override
  String expiresDate(DateTime date) =>
      'Expires: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override String productQuantity(String name, int quantity) => '$name × $quantity';
}
