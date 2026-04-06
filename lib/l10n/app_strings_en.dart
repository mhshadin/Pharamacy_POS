import 'app_strings.dart';

class AppStringsEn implements AppStrings {
  // ── Navigation & App Info ──────────────────────────
  @override
  String get navDashboard => 'Dashboard';
  @override
  String get navAddProduct => 'Add Product';
  @override
  String get navReturns => 'Returns';
  @override
  String get navSalesReport => 'Sales Report';
  @override
  String get navExpiringSoon => 'Expiring Soon';
  @override
  String get navLowStock => 'Low Stock';
  @override
  String get navProductList => 'Product List';
  @override
  String get navTopProducts => 'Top Products';
  @override
  String get navSettings => 'Settings';
  @override
  String get navProfile => 'Profile';
  @override
  String get navNotifications => 'Notifications';
  @override
  String get navBackToPos => 'Back to POS';
  @override
  String get appName => 'Pharmacy POS';
  @override
  String get posTitle => 'PharmaPOS';
  @override
  String get adminPortal => 'ADMIN PORTAL';
  @override
  String get backToPos => 'Back to POS';

  // ── POS / Home Screen ──────────────────────────────
  @override
  String get saleComplete => 'Sale Complete';
  @override
  String get clearCart => 'Clear Cart?';
  @override
  String get clearCartConfirm => 'Are you sure you want to clear the cart?';
  @override
  String get newSale => 'New Sale';
  @override
  String get cancelBtn => 'Cancel';
  @override
  String get yesClr => 'Yes, Clear';
  @override
  String get addedToCart => 'Added to cart';
  @override
  String get noMatchVoice =>
      'No match – edit the name and tap the search icon.';
  @override
  String get barcodeNotFound => 'Product not found for barcode';
  @override
  String get readingStrip => 'Reading strip...';
  @override
  String get noMedicineDetected => 'No medicine names detected. Try again.';
  @override
  String get successCharged => 'Successfully charged';
  @override
  String get successfullyCharged => 'Successfully charged';
  @override
  String get listening => 'Listening...';
  @override
  String get searchHint => 'Search medicine name or generic...';
  @override
  String get voiceSearchHint => 'Edit and tap search...';
  @override
  String get menuTooltip => 'Menu';
  @override
  String get searchTooltip => 'Search products';
  @override
  String get closeSearchTooltip => 'Close search';
  @override
  String get alertsTooltip => 'Alerts';
  @override
  String get searchBtnTooltip => 'Search';
  @override
  String get discardBtnTooltip => 'Discard';
  @override
  String get saleCompleteInvoice => 'Sale Complete! Invoice:';

  // ── Admin Dashboard ────────────────────────────────
  @override
  String get overview => 'Overview';
  @override
  String get todaysSales => "Today's Sales";
  @override
  String get todaySales => "Today's Sales";
  @override
  String get totalOrders => 'Total Orders';
  @override
  String get lowStock => 'Low Stock';
  @override
  String get expiringSoon => 'Expiring Soon';
  @override
  String get criticalInventory => 'Critical Inventory';
  @override
  String get allStockGood => 'All stock is good! 🎉';
  @override
  String get noLowStockExpiring => 'No low stock or expiring items.';
  @override
  String get recentTransactions => 'Recent Transactions';
  @override
  String get lowStockBadge => 'Low Stock';
  @override
  String get expiringSoonBadge => 'Expiring Soon';
  @override
  String get unknownExpiry => 'Unknown Expiry';
  @override
  String get expiresPrefix => 'Expires: ';
  @override
  String lastUpdated(String dateTime) => 'Last Updated: $dateTime';
  @override
  String get units => 'Units';
  @override
  String get pcsSuffix => 'pcs';

  // ── Notifications ─────────────────────────────
  @override
  String lowStockSubtitle(int strips) =>
      'Item is low on stock ($strips strips left)';
  @override
  String expiresOnDate(String date) => 'Expires on $date';
  @override
  String get notificationLowStockTitle => 'Low Stock Alert ⚠️';
  @override
  String notificationLowStockBody(String productName, int stock) =>
      '$productName is low in stock ($stock remaining). Please restock soon.';
  @override
  String get notificationExpiryTitle => 'Expiry Warning ⌛';
  @override
  String notificationExpiryBody(String productName, String expiryDate) =>
      '$productName is expiring on $expiryDate. Check your inventory.';
  @override
  String get alarmInventoryCheckTitle => '⏰ Inventory Check Reminder';
  @override
  String get alarmInventoryCheckBody =>
      'Time to check low stock and expiring soon products!';
  @override
  String get alarmStockReminderTitle => 'Stock Reminder';
  @override
  String get alarmStockReminderBody => 'It is time to check your inventory!';
  @override
  String get alarmStockExpiryReminderTitle => 'Stock & Expiry Reminder';
  @override
  String get alarmStockExpiryReminderBody =>
      'Check your inventory for low stock or expiring meds.';
  @override
  String get alarmDismiss => 'Dismiss';

  // ── Top Products ───────────────────────────────
  @override
  String get topProductsToday => 'Today';
  @override
  String get topProductsWeek => 'Week';
  @override
  String get topProductsMonth => 'Month';
  @override
  String get topProductsYear => 'Year';
  @override
  String get topProductsAllTime => 'All Time';
  @override
  String get revenueLabel => 'REVENUE';
  @override
  String boxesSoldSuffix(double n) => '$n boxes sold';

  // ── Product Management ─────────────────────────────
  @override
  String get productList => 'Product List';
  @override
  String get searchProducts => 'Search Products';
  @override
  String get editBtn => 'Edit';
  @override
  String get restockBtn => 'Restock';
  @override
  String get noProductsFound => 'No products found';
  @override
  String get deleteProduct => 'Delete Product?';
  @override
  String get deleteProductConfirm =>
      'Are you sure you want to delete this product?';
  @override
  String get deleteBtn => 'Delete';
  @override
  String get productDeleted => 'Product deleted successfully';
  @override
  String get addProduct => 'Add Product';
  @override
  String get editProduct => 'Edit Product';
  @override
  String get productName => 'Product Name';
  @override
  String get genericName => 'Generic Name';
  @override
  String get category => 'Category';
  @override
  String get pricePerPc => 'Price per Pc';
  @override
  String get pricePerStrip => 'Price per Strip';
  @override
  String get pcsPerStrip => 'Pcs per Strip';
  @override
  String get stockBoxes => 'Stock Boxes';
  @override
  String get pcsPerBox => 'Pcs per Box';
  @override
  String get minStockLevel => 'Min Stock Level';
  @override
  String get expiryDate => 'Expiry Date';
  @override
  String get supplierName => 'Supplier Name';
  @override
  String get supplierPhone => 'Supplier Phone';
  @override
  String get saveProduct => 'Save Product';
  @override
  String get productSaved => 'Product saved successfully';
  @override
  String get productUpdated => 'Product updated successfully';
  @override
  String get requiredField => 'Required field';
  @override
  String get restock => 'Restock';
  @override
  String get restockTitle => 'Restock Product';
  @override
  String get boxesToAdd => 'Boxes to add';
  @override
  String get confirmRestock => 'Confirm Restock';
  @override
  String get restockSuccess => 'Restock successful';
  @override
  String get stockStrips => 'strips';
  @override
  String get stockPcs => 'pieces';
  @override
  String get pcsRemaining => 'pcs remaining';
  @override
  String get minStock => 'min';

  // ── Restock Screen ─────────────────────────────
  @override
  String get pleaseSelectExpiryDate => 'Please select an expiry date.';
  @override
  String get enterBoxesOrStrips => 'Enter boxes or strips to add.';
  @override
  String get failedToAddStock => 'Failed to add stock. Please try again.';
  @override
  String currentStock(int boxes, int strips, int pcs) =>
      'Current stock: $boxes boxes • $strips strips • $pcs pcs';
  @override
  String currentExpiry(String date) => 'Current expiry (product): $date';
  @override
  String packagingInfo(int spb, int pps) =>
      'Packaging: $spb strips/box • $pps pcs/strip';
  @override
  String get batchAndExpiry => 'Batch & expiry';
  @override
  String get quantityToAdd => 'Quantity to add';
  @override
  String get batchNoOptional => 'Batch No (optional)';
  @override
  String newBatchExp(String date) => 'New batch exp: $date';
  @override
  String get selectExpiryForBatch => 'Select expiry for new batch*';
  @override
  String get addingLabel => 'Adding…';
  @override
  String get addStock => 'Add stock';

  // ── Buying Price & Profit ───────────────────
  @override
  String get buyingPriceSection => 'Buying Price (Cost)';
  @override
  String get buyingPricePerPc => 'Buying Price / Box (৳)';
  @override
  String get buyingPriceHelper =>
      'Pre-filled from last batch based on box price. Update if price changed.';
  @override
  String get sellingPricePerPc => 'Selling Price / Box (৳)';
  @override
  String get sellingPriceHelper =>
      'Optional. Enter only if you want to update the product selling price per box.';
  @override
  String profitPreview(String amount, String margin, bool isLoss) => isLoss
      ? 'Loss: ৳$amount/strip ($margin%)'
      : 'Profit: ৳$amount/strip ($margin% margin)';
  @override
  String get navProfitReport => 'Profit Report';
  @override
  String get profitReport => 'Profit Report';
  @override
  String get grossProfit => 'Gross Profit';
  @override
  String get totalCost => 'Total Cost';
  @override
  String get profitMargin => 'Profit Margin';
  @override
  String get viewProfitReport => 'View Profit Report';
  @override
  String get noCostData => 'No cost data — set buying price when restocking';
  @override
  String get profitReportEmpty => 'No sales data for this period';
  @override
  String get productBreakdown => 'Product Breakdown';

  // ── Filtering & Sorting ────────────────────────────
  @override
  String get filterByCompany => 'Filter by Company';
  @override
  String get filterByGeneric => 'Filter by Generic';
  @override
  String get filterByType => 'Filter by Type';
  @override
  String get filterByStockStatus => 'Filter by stock status';
  @override
  String get filterByExpiryUrgency => 'Filter by expiry urgency';
  @override
  String get searchCompanies => 'Search companies...';
  @override
  String get searchGenerics => 'Search generics...';
  @override
  String get clearAll => 'Clear All';
  @override
  String get applyBtn => 'Apply';
  @override
  String get deleteProducts => 'Delete Products';
  @override
  String get deleteConfirm => 'Are you sure you want to delete these products?';
  @override
  String get sortBtn => 'Sort';
  @override
  String get sortUrgency => 'Urgency (Recommended)';
  @override
  String get sortExpiry => 'Expiry: Soonest First';
  @override
  String get sortNameAZ => 'Name: A → Z';
  @override
  String get sortPriceHighLow => 'Price: High → Low';
  @override
  String get sortPriceLowHigh => 'Price: Low → High';
  @override
  String get noCompaniesFound => 'No companies found';
  @override
  String get noGenericsFound => 'No generics found';
  @override
  String get selectItems => 'Select Items';
  @override
  String get cancelSelection => 'Cancel Selection';
  @override
  String get deleteSelected => 'Delete Selected';
  @override
  String get sortNewest => 'Newest First';
  @override
  String get sortOldest => 'Oldest First';
  @override
  String get sortHighToLow => 'Amount: High to Low';
  @override
  String get sortLowToHigh => 'Amount: Low to High';

  // ── Settings & Auth ───────────────────────────────
  @override
  String get signInToStart => 'Sign in to start selling';
  @override
  String get emailLabel => 'Email';
  @override
  String get passwordLabel => 'Password';
  @override
  String get signInBtn => 'Sign in';
  @override
  String get continueWithGoogle => 'Continue with Google';
  @override
  String get orCreateAccount => 'Or create an account';
  @override
  String get createPharmacyAccount => 'Create Pharmacy Account';
  @override
  String get createAccountBtn => 'Create account';
  @override
  String get fullNameLabel => 'Your full name';
  @override
  String get pharmacyNameLabel => 'Pharmacy / business name';
  @override
  String get passwordMinChars => 'Password (min 8 characters)';
  @override
  String get confirmPasswordLabel => 'Confirm password';
  @override
  String get validationEnterEmail => 'Please enter your email';
  @override
  String get validationValidEmail => 'Please enter a valid email';
  @override
  String get validationEnterPassword => 'Please enter your password';
  @override
  String get validationPasswordMin => 'Password must be at least 8 characters';
  @override
  String get validationEnterName => 'Please enter your name';
  @override
  String get validationEnterBusiness => 'Please enter your business name';
  @override
  String get validationConfirmPassword => 'Please confirm your password';
  @override
  String get validationPasswordsNoMatch => 'Passwords do not match';
  @override
  String get loginFailed => 'Login failed. Please try again.';
  @override
  String get registrationFailed => 'Registration failed. Please try again.';
  @override
  String get googleSignInFailed => 'Google sign-in failed. Please try again.';
  @override
  String get inventoryAlerts => 'Inventory Alerts';
  @override
  String get lowStockThreshold => 'Low Stock Threshold (Boxes)';
  @override
  String get lowStockThresholdHelper =>
      'Default warning level in boxes. Individual products can override this.';
  @override
  String get defaultBoxesToOrder => 'Default Boxes to Order';
  @override
  String get defaultBoxesHelper =>
      'This is pre-filled when exporting an order list from Low Stock / Expiring Soon.';
  @override
  String get expiringSoonWindow => 'Expiring Soon Window (Days)';
  @override
  String get expiringSoonWindowHelper =>
      'Products expiring within this many days appear in Expiring Soon.';
  @override
  String get moderateExpiry => 'Moderate Expiry (Days, Amber)';
  @override
  String get moderateExpiryHelper =>
      'Amber highlight: expires within this many days but after the critical (red) range.';
  @override
  String get criticalExpiry => 'Critical Expiry (Days, Red)';
  @override
  String get criticalExpiryHelper =>
      'Red highlight: expires within this many days (and expired stock).';
  @override
  String get defaultExpiryDelay => 'Default Expiry Delay (Months)';
  @override
  String get defaultExpiryDelayHelper =>
      'The initial date in the Add Product date picker will be set to this many months from today.';
  @override
  String get showSupplierInfo => 'Show Supplier Info in Add Product';
  @override
  String get showSupplierInfoHelper =>
      'Enable this to enter and track supplier name and phone number during stock in.';
  @override
  String get addProductDefaultStepperMode =>
      'Use Stepper Mode by default in Add Product';
  @override
  String get addProductDefaultStepperModeHelper =>
      'When enabled, Add Product opens in step-by-step mode by default.';
  @override
  String get addProductStepperModeToggle => 'Stepper Mode';
  @override
  String get expandOptionalFields => 'Always expand optional fields';
  @override
  String get expandOptionalFieldsHelper =>
      'When adding many new products, keep generic name and company fields expanded by default.';
  @override
  String get restockPricingCollapsedByDefault =>
      'Keep Restock Pricing collapsed by default';
  @override
  String get restockPricingCollapsedByDefaultHelper =>
      'If enabled, the Pricing section starts collapsed in the Restock screen.';
  @override
  String get optionalDetails => 'Optional Details';
  @override
  String get saveSettings => 'Save Settings';
  @override
  String get settingsSaved => 'Settings saved successfully';
  @override
  String get expiryOrderError =>
      'Expiry days must be ordered: Critical (red) ≤ Moderate (amber) ≤ Expiring Soon window.';
  @override
  String get databaseBackup => 'Database Backup';
  @override
  String get googleDriveIntegration => 'Google Drive Integration';
  @override
  String get googleDriveDesc =>
      'Securely backup your database to Google Drive.';
  @override
  String get notSyncedYet => 'Not synced yet';
  @override
  String get syncingNow => 'Syncing now...';
  @override
  String get syncFailed => 'Sync failed';
  @override
  String get lastSync => 'Last sync';
  @override
  String get missingDriveScope =>
      'Missing Drive scope. Please sign out and sign back in.';
  @override
  String get ensureSignedIn => 'Ensure you are signed in and have internet.';
  @override
  String get syncNow => 'Sync Now';
  @override
  String get phoneStorageBackup => 'Phone Storage Backup';
  @override
  String get offlineBackupImport => 'Offline Backup & Import';
  @override
  String get offlineBackupDesc =>
      'Export a backup file to your phone storage or import an existing .db file.';
  @override
  String get exportNow => 'Export Now';
  @override
  String get importDb => 'Import DB';
  @override
  String get exportedSuccess => 'Database exported to phone storage';
  @override
  String get importDatabase => 'Import Database?';
  @override
  String get importDatabaseWarning =>
      'This will REPLACE all your current data. This action cannot be undone.';
  @override
  String get importReplace => 'Import & Replace';
  @override
  String get importSuccess => 'Import successful!';
  @override
  String get importFailed => 'Import failed';
  @override
  String get medicineCategories => 'Medicine Categories';
  @override
  String get medicineCategoriesDesc => 'Manage types like Tablet, Syrup, etc.';
  @override
  String get addNewType => 'Add new type (e.g. Inhaler)';
  @override
  String get removeCategory => 'Remove Category?';
  @override
  String get removeCategoryConfirm => 'Are you sure you want to remove';
  @override
  String get removeCategoryWarning =>
      'Existing products with this category will keep it until they are edited.';
  @override
  String get removeBtn => 'Remove';
  @override
  String get languageSetting => 'Language';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageBangla => 'বাংলা';
  @override
  String get logout => 'Logout';
  @override
  String get logoutConfirm => 'Are you sure you want to logout?';
  @override
  String get notifications => 'Notifications';

  // ── Reports & Others ──────────────────────────────
  @override
  String get returnsTitle => 'Returns';
  @override
  String get filterReturns => 'Filter Returns';
  @override
  String get dateRange => 'Date Range';
  @override
  String get amountRange => 'Amount Range (৳)';
  @override
  String get timeRange => 'Time Range';
  @override
  String get anyTime => 'Any time';
  @override
  String get clearTime => 'Clear Time';
  @override
  String get returnItems => 'Return Items';
  @override
  String get confirmReturn => 'Confirm Return';
  @override
  String get noItemsInvoice => 'No items to load from this invoice.';
  @override
  String get allItemsReturned =>
      'All items in this invoice are already returned.';
  @override
  String get someProductsSkipped => 'Some products were skipped';
  @override
  String get couldNotFindProducts => 'Could not find product(s)';
  @override
  String get returnItemsFor => 'Return items for';
  @override
  String get strips => 'Strips';
  @override
  String get pcs => 'Pcs';
  @override
  String get maxReturnable => 'Max returnable';
  @override
  String get selected => 'Selected';
  @override
  String get changeBtn => 'Change';
  @override
  String get salesReport => 'Sales Report';
  @override
  String get totalRevenue => 'Total Revenue';
  @override
  String get totalTransactions => 'Total Transactions';
  @override
  String get topProduct => 'Top Product';
  @override
  String get noSalesData => 'No sales data for this period';
  @override
  String get exportPdf => 'Export PDF';
  @override
  String get exportCsv => 'Export CSV';
  @override
  String get exportSuccess => 'Report exported successfully';
  @override
  String get exportFailed => 'Failed to export report';
  @override
  String get today => 'Today';
  @override
  String get thisWeek => 'This Week';
  @override
  String get thisMonth => 'This Month';
  @override
  String get last3Months => 'Last 3 Months';
  @override
  String exportError(String error) => 'Error exporting report: $error';
  @override
  String get reportSaved => 'Report saved successfully!';
  @override
  String get reportFailed => 'Failed to save the report.';
  @override
  String get transactionHistory => 'Transaction History';
  @override
  String recordsCount(int count) => '$count records';
  @override
  String get orders => 'Orders';
  @override
  String get itemsSold => 'Items Sold';
  @override
  String get noTransactionsFound => 'No transactions found';
  @override
  String get tryAnotherFilter => 'Try a different date range or filter';
  @override
  String get revenueTrend => 'Revenue Trend';
  @override
  String get period => 'Period';
  @override
  String get customRange => 'Custom range';
  @override
  String get custom => 'Custom';
  @override
  String get last30Days => 'Last 30 Days';
  @override
  String get weekly => 'Weekly';
  @override
  String get monthly => 'Monthly';
  @override
  String get yearly => 'Yearly';
  @override
  String get newestFirst => 'Newest First';
  @override
  String get oldestFirst => 'Oldest First';
  @override
  String get amountHigh => 'Amount (High)';
  @override
  String get amountLow => 'Amount (Low)';
  @override
  String get productAZ => 'Product A-Z';
  @override
  String get mon => 'Mon';
  @override
  String get tue => 'Tue';
  @override
  String get wed => 'Wed';
  @override
  String get thu => 'Thu';
  @override
  String get fri => 'Fri';
  @override
  String get sat => 'Sat';
  @override
  String get sun => 'Sun';
  @override
  String get jan => 'Jan';
  @override
  String get feb => 'Feb';
  @override
  String get mar => 'Mar';
  @override
  String get apr => 'Apr';
  @override
  String get may => 'May';
  @override
  String get jun => 'Jun';
  @override
  String get jul => 'Jul';
  @override
  String get aug => 'Aug';
  @override
  String get sep => 'Sep';
  @override
  String get oct => 'Oct';
  @override
  String get nov => 'Nov';
  @override
  String get dec => 'Dec';
  @override
  String get others => 'Others';
  @override
  String get expiringSoonTitle => 'Expiring Soon';
  @override
  String get lowStockTitle => 'Low Stock Products';
  @override
  String get exportOrderList => 'Export Order List';
  @override
  String get noExpiringSoon => 'No products expiring soon';
  @override
  String get noLowStock => 'No products in low stock';
  @override
  String get remainingPcs => 'remaining pcs';
  @override
  String get boxesSuffix => 'boxes';
  @override
  String get stripsSuffix => 'strips';
  @override
  String get notificationsTitle => 'Notifications';
  @override
  String get noNotifications => 'No notifications';
  @override
  String get markAllRead => 'Mark all as read';
  @override
  String get profileTitle => 'Profile';
  @override
  String get signOut => 'Sign Out';
  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';
  @override
  String get accountInfo => 'Account Information';
  @override
  String get changePassword => 'Change Password';
  @override
  String get currentPassword => 'Current Password';
  @override
  String get newPassword => 'New Password';
  @override
  String get updatePassword => 'Update Password';
  @override
  String get passwordUpdated => 'Password updated successfully';

  // ── Profile Screen Extension ───────────────────
  @override
  String get emailAddress => 'Email Address';
  @override
  String get subscriptionValidUntil => 'Subscription Valid Until';
  @override
  String get subscriptionManagement => 'Subscription Management';
  @override
  String get activeSubscription => 'Active Subscription';
  @override
  String get expiredInactive => 'Expired / Inactive';
  @override
  String get activateBtn => 'Activate';
  @override
  String get renewalDate => 'Renewal Date';
  @override
  String get editDisplayName => 'Edit Display Name';
  @override
  String get editPhoneNumber => 'Edit Phone Number';
  @override
  String get updateAdminPin => 'Update Admin PIN';
  @override
  String get setLocalPassword => 'Set Local Password';
  @override
  String get setLocalPasswordSubtitle =>
      'Create a password to also log in via email';
  @override
  String get googleManagedAccount => 'Google Managed Account';
  @override
  String get googleManagedSubtitle => 'You log in using your Google identity';
  @override
  String get newDisplayName => 'New Display Name';
  @override
  String get nameRequired => 'Name is required';
  @override
  String get max100Chars => 'Max 100 characters';
  @override
  String get currentPin => 'Current PIN';
  @override
  String get newPin => 'New PIN';
  @override
  String get confirmPin => 'Confirm PIN';
  @override
  String get pinUpdated => 'PIN updated successfully!';
  @override
  String get incorrectPin => 'Incorrect current PIN.';
  @override
  String get nameUpdated => 'Name updated successfully!';
  @override
  String get phoneUpdated => 'Phone number updated successfully!';
  @override
  String get saveNameBtn => 'Save Name';
  @override
  String get savePhoneBtn => 'Save Phone Number';
  @override
  String get phoneNumberLabel => 'Phone Number';
  @override
  String get newPhoneNumber => 'New Phone Number';
  @override
  String get phoneRequired => 'Phone number is required';
  @override
  String get phoneMustBe11Digits => 'Phone number must be exactly 11 digits';
  @override
  String get phoneDigitsOnly => 'Phone number must contain digits only';
  @override
  String get updateSecurityPin => 'Update Security PIN';
  @override
  String get secureLocalAccount => 'Secure Local Account';
  @override
  String get pinsDoNotMatch => 'PINs do not match';
  @override
  String get minFourDigits => 'Min 4 digits';
  @override
  String get adminAccessSecurity => 'Admin access';
  @override
  String get biometricUnlockAdmin => 'Unlock admin with biometrics';
  @override
  String get biometricUnlockAdminHelper =>
      'Use fingerprint, Face ID, or your device’s biometric to open the admin portal quickly. PIN stays available as a backup.';
  @override
  String get biometricNotAvailable =>
      'Biometrics are currently unavailable on this device.';
  @override
  String get biometricSetupRequired =>
      'Set up fingerprint or face unlock in your phone settings, then try again.';
  @override
  String get biometricLockedOut =>
      'Biometrics are locked. Unlock your device once, then try again.';
  @override
  String get biometricTryAgainLater =>
      'Too many attempts. Please try biometric authentication again in a moment.';
  @override
  String get biometricCanceled => 'Biometric authentication was canceled.';
  @override
  String get biometricPromptEnable =>
      'Confirm with your fingerprint or face to turn on biometric admin unlock.';
  @override
  String get biometricPromptDisable =>
      'Confirm with your fingerprint or face to turn off biometric admin unlock.';
  @override
  String get biometricAuthFailed => 'Biometric authentication did not succeed.';
  @override
  String get adminLoginTitle => 'Admin login';
  @override
  String get adminLoginEnterPin => 'Enter admin PIN to continue';
  @override
  String get adminLoginWrongPin => 'Wrong PIN. Try again.';
  @override
  String get adminLoginPinEmpty => 'Please enter the PIN';
  @override
  String get adminLoginBtn => 'Login';
  @override
  String get adminPinSetupTitle => 'Set admin PIN';
  @override
  String get adminPinSetupSubtitle =>
      'First-time setup: create your admin PIN to continue';
  @override
  String get adminPinSetupBtn => 'Set PIN';
  @override
  String get adminPinSetupFailed => 'Failed to set admin PIN.';
  @override
  String get biometricUnlockReason => 'Unlock admin portal';
  @override
  String get biometricUseFace => 'Use Face ID';
  @override
  String get biometricUseFingerprint => 'Use fingerprint';
  @override
  String get biometricUseGeneric => 'Use biometrics';
  @override
  String get passwordSet => 'Password set successfully!';
  @override
  String get adminRole => 'Admin';
  @override
  String get renew => 'Renew';
  @override
  String get activate => 'Activate';
  @override
  String get required => 'Required';
  @override
  String get min8Chars => 'Min 8 characters';
  @override
  String get confirmPassword => 'Confirm Password';
  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  // ── Product Edit Extension ─────────────────────
  @override
  String get genericDescription => 'Generic / Description';
  @override
  String get companyNameOptional => 'Company Name (optional)';
  @override
  String get supplierNameOptional => 'Supplier Name (optional)';
  @override
  String get supplierPhoneOptional => 'Supplier Phone (optional)';
  @override
  String get barcodeOptional => 'Barcode (optional)';
  @override
  String get expiryDateOptional => 'Expiry Date (optional)';
  @override
  String get pricePerStripLabel => 'Price / Strip';
  @override
  String get pricePerPcLabel => 'Price / Pc';
  @override
  String get lowStockWarningBox => 'Low Stock Warning (Box)';
  @override
  String get activeBatches => 'Active Batches';
  @override
  String get noActiveBatches => 'No active batches. Stock is 0.';
  @override
  String pcsSuffixCount(int n) => '$n pcs';
  @override
  String get saveChanges => 'Save Changes';
  @override
  String get medicineType => 'Medicine Type';
  @override
  String get powerLabel => 'Power';
  @override
  String get powerHint => 'e.g. 200mg, 5ml, 1g';
  @override
  String editProductTitle(String name) => 'Edit: $name';
  @override
  String get productDetailsTitle => 'Product Details';
  @override
  String batchRemaining(int str, int pcs) => '($str str + $pcs)';

  // ── Bulk Import Screen ──────────────────────────
  @override
  String get noFileSelected => 'No file selected';
  @override
  String selectedFile(String name) => 'File: $name';
  @override
  String get selectCsvExcel => 'Select CSV/Excel';
  @override
  String get showFileStructure => 'Show file structure example';
  @override
  String get uploadCsvHint =>
      'Upload a CSV or Excel file to preview your products before importing.';
  @override
  String get xlsNotSupported =>
      'Legacy .xls files are not supported. Please use .xlsx or .csv';
  @override
  String unsupportedFileType(String ext) => 'Unsupported file type: $ext';
  @override
  String readyToImport(int n) => 'Ready to Import ($n)';
  @override
  String errorsCount(int n) => 'Errors ($n)';
  @override
  String get confirmImport => 'Confirm Import';
  @override
  String confirmImportMsg(int n) =>
      'Are you sure you want to import $n items into your inventory?';
  @override
  String get yesImport => 'Yes, import';
  @override
  String importNItems(int n) => 'Import $n Items';
  @override
  String get noValidProducts => 'No valid products found.';
  @override
  String get noErrorsFound => 'No errors found! You are good to go.';
  @override
  String get boxPrice => 'Box Price';
  @override
  String get stockPcsLabel => 'Stock Pcs';
  @override
  String get xlsLegacyNotSupported =>
      'Legacy .xls files are not supported. Please save as .xlsx or CSV.';
  @override
  String get failedToReadFile => 'Failed to read file. Please try again.';
  @override
  String get fileIsEmpty => 'The selected file is empty.';
  @override
  String missingRequiredColumn(String col) => 'Missing required column: $col';
  @override
  String rowSkippedNameEmpty(int row) =>
      'Row $row: Product name cannot be empty. Row skipped.';
  @override
  String invalidExpiryUsingDefault(int row, String val) =>
      'Row $row: Invalid ExpiryDate \'$val\'; using default 1 year.';
  @override
  String rowSkippedDataError(int row, String err) =>
      'Row $row: Data format error. Row skipped. ($err)';
  @override
  String get noValidRowsFound =>
      'No valid rows were found. Please review the error list.';
  @override
  String bulkImportSuccess(int n) => '$n products imported to database safely!';
  @override
  String databaseInsertFailed(String err) =>
      'Database Batch Insert Failed: $err';
  @override
  String get failedToImportReviewErrors =>
      'Failed to import products into the database. Please review the errors.';
  @override
  String get bulkImportPreview => 'Bulk Import Preview';
  @override
  String get editThisRow => 'Edit this row';
  @override
  String get deleteThisRow => 'Delete this row from import';
  @override
  String get subscriptionTitle => 'Subscription';
  @override
  String subscriptionRenewalDaysLeft(int daysRemaining) {
    if (daysRemaining < 0) return 'Expired';
    if (daysRemaining == 0) return 'Expires today';
    if (daysRemaining == 1) return '1 day left';
    return '$daysRemaining days left';
  }

  @override
  String get subscriptionRenewalUnavailable => 'No renewal date';
  @override
  String get subscribeBtn => 'Subscribe Now';
  @override
  String get currentPlan => 'Current Plan';
  @override
  String get expiresOn => 'Expires on';
  @override
  String get trialExpired => 'Trial Expired';
  @override
  String get renewBtn => 'Renew Subscription';
  @override
  String get ocrScanResult => 'OCR Results';
  @override
  String get addAllToCart => 'Add all to cart';
  @override
  String get confirmedItems => 'Confirmed Items';
  @override
  String get generalInfo => 'General Information';
  @override
  String get packaging => 'Packaging';
  @override
  String get pricing => 'Pricing';
  @override
  String get inventory => 'Inventory';
  @override
  String get expiryBatch => 'Expiry / Batch';
  @override
  String get supplierInfo => 'Supplier Information';
  @override
  String get selectExpiryDate =>
      'Please select an expiry date for trackable stock.';
  @override
  String get batchNumber => 'Batch Number';
  @override
  String get barcodeLabel => 'Barcode (optional)';
  @override
  String get scanBtn => 'Scan';
  @override
  String get stripsPerBox => 'Strips per Box';
  @override
  String get failedToSaveProduct => 'Failed to save product. Please try again.';
  @override
  String get noDate => 'No Date';
  @override
  String get bulkImport => 'Bulk Import';
  @override
  String get wizardBack => 'Back';
  @override
  String get wizardContinue => 'Continue';
  @override
  String get changeMedType => 'Change Medicine Type';
  @override
  String get returns => 'Returns';
  @override
  String get searchBtn => 'Search';
  @override
  String get searchHelpText => 'Search by Invoice No. or Product Name';
  @override
  String get noResults => 'No results found';
  @override
  String get fullyReturned => 'Fully Returned';
  @override
  String get qtyLabel => 'Qty';
  @override
  String get retLabel => 'Ret';
  @override
  String get batchLabel => 'Batch';
  @override
  String get returnsProcessed => 'Returns processed successfully!';
  @override
  String get sortBy => 'Sort By';
  @override
  String get sortAmountHigh => 'Amount: High to Low';
  @override
  String get sortAmountLow => 'Amount: Low to High';
  @override
  String get filters => 'Filters';

  // ── Common / Shared ───────────────────────────────
  @override
  String get loading => 'Loading...';
  @override
  String get error => 'Error';
  @override
  String get success => 'Success';
  @override
  String get tryAgain => 'Try again';
  @override
  String get toLabel => 'to';
  @override
  String get close => 'Close';
  @override
  String get open => 'Open';
  @override
  String get confirm => 'Confirm';
  @override
  String get apply => 'Apply';
  @override
  String get search => 'Search';
  @override
  String get filter => 'Filter';
  @override
  String get sort => 'Sort';
  @override
  String get noResultsFound => 'No results found';
  @override
  String get boxes => 'Boxes';
  @override
  String get minAmount => 'Min ৳';
  @override
  String get maxAmount => 'Max ৳';

  @override
  String get deselectAll => 'Deselect All';
  @override
  String get selectAll => 'Select All';
  @override
  String selectedCount(int count) => '$count Selected';
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

  @override
  String get productListEmpty => 'Your product list is currently empty.';
  @override
  String get noProductsMatchCriteria =>
      'No products match your search/filter criteria.';
  @override
  String get clearAllFilters => 'Clear All Filters';
  @override
  String get inStock => 'In Stock';
  @override
  String get pieces => 'Pcs';
  @override
  String get stripPrice => 'Strip ৳';
  @override
  String get edit => 'Edit';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get saveBtn => 'Save';
  @override
  String unitPrice(String unit) => '$unit PRICE';
  @override
  String addedToCartDetail(String name, int qty, String unit) =>
      'Added $name ($qty $unit) to cart';
  @override
  String get noCloseMatchFound => 'No close match found. Please edit the name.';
  @override
  String deleteProductsConfirmation(int count) =>
      'Are you sure you want to delete $count products?';

  @override
  String get deleteSelectedTooltip => 'Delete Selected';
  @override
  String get taka => 'Taka';
  @override
  String get companyName => 'Company Name';
  @override
  String get scan => 'Scan';
  @override
  String get exp => 'Exp';
  @override
  String get syrupHint => 'e.g. 100 ml per bottle';
  @override
  String get tube => 'Tube';
  @override
  String get vial => 'Vial';
  @override
  String get bottle => 'Bottle';
  @override
  String get sachet => 'Sachet';
  @override
  String get inhaler => 'Inhaler';
  @override
  String get patch => 'Patch';
  @override
  String get unit => 'Unit';
  @override
  String get ml => 'ml';
  @override
  String get grams => 'g';
  @override
  String get price => 'Price';
  @override
  String get invoicePrefix => 'Invoice:';
  @override
  String get onePcSuffix => ' (1 pc)';
  @override
  String voiceError(String error) => 'Voice error: $error';
  @override
  String ocrError(String error) => 'OCR error: $error';
  @override
  String get googleIdTokenError => 'Unable to get Google ID token.';
  @override
  String get createAccount => 'Create Account';
  @override
  String get unknownInvoice => 'Unknown Invoice';

  // --- Parameterized ---
  @override
  String productStockDetails(int boxes, int strips, int pcs, int min) =>
      '$boxes boxes • $strips strips • $pcs pcs remaining (min: $min)';

  @override
  String expiresDate(DateTime date) =>
      'Expires: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  String productQuantity(String name, int quantity) => '$name × $quantity';

  @override
  String get fileStructureExample => 'File structure example (CSV / Excel)';
  @override
  String get expiryFormatHint =>
      'ExpiryDate format: YYYY-MM-DD. BatchNo is optional.';
  @override
  String get csvTemplateSuccess => 'CSV template downloaded successfully.';
  @override
  String get csvTemplateFail => 'Failed to download CSV template.';
  @override
  String get excelTemplateSuccess => 'Excel template downloaded successfully.';
  @override
  String get excelTemplateFail => 'Failed to download Excel template.';
  @override
  String get downloadCsvTemplate => 'Download CSV Template';
  @override
  String get downloadExcel => 'Download Excel';
  @override
  String get rawCsvExample => 'Raw CSV example (full structure):';
  @override
  String get editImportedProduct => 'Edit Imported Product';
  @override
  String get pricingPackaging => 'Pricing & Packaging';
  @override
  String get inventoryTracking => 'Inventory & Tracking';
  @override
  String get saveChangesLabel => 'Save Changes';
  @override
  String get selectExpiryDateError => 'Please select an expiry date.';
  @override
  String get requiredLabel => 'Required';
  @override
  String get mustBeGreaterThanZero => 'Must be > 0';
  @override
  String get minStockWarningBox => 'Low Stock Warning (Box)';
  @override
  String get productNameLabel => 'Product Name';
  @override
  String get barcodeLabelOptional => 'Barcode (optional)';
  @override
  String get stripsPerBoxLabel => 'Strips per Box';
  @override
  String get pcsPerStripLabel => 'Pieces per Strip';
  @override
  String get pricePerBoxLabel => 'Price / Box';
  @override
  String get stockInBoxesLabel => 'Stock (Boxes)';
  @override
  String get selectExpiry => 'Select Expiry';
  @override
  String get medTypeLabel => 'Medicine Type';
  @override
  String get supplierNameLabel => 'Supplier Name';
  @override
  String get supplierPhoneLabel => 'Supplier Phone';

  // ── Expiring Soon & Low Stock ──────────────────────
  @override
  String allProductsValidForDays(int days) =>
      'All products have more than $days days until expiry.';
  @override
  String get filterAll => 'All';
  @override
  String get filterCritical => 'Critical';
  @override
  String get filterWarning => 'Warning';
  @override
  String get filterNotice => 'Notice';
  @override
  String get allCompanies => 'All Companies';
  @override
  String nCompanies(int n) => '$n Companies';
  @override
  String productsCount(int n) => '$n product${n == 1 ? '' : 's'}';
  @override
  String get sortSoonestFirst => 'Soonest First';
  @override
  String get sortLatestFirst => 'Latest First';
  @override
  String get sortNameZA => 'Z → A';
  @override
  String get setOrderQuantities => 'Set Order Quantities';
  @override
  String get enterBoxesToOrder =>
      'Enter how many boxes to order for each product.';
  @override
  String get next => 'Next';
  @override
  String get filterOutOfStock => 'Out of Stock';
  @override
  String get sortMostUrgent => 'Most Urgent';
  @override
  String get sortBiggestDeficit => 'Biggest Deficit';
  @override
  String get confirmOrderQuantities => 'Confirm Order Quantities';
  @override
  String deficitUnits(int n, String unit) => 'Deficit: $n $unit';

  @override
  String get callSupplier => 'Call supplier';

  @override
  String remainingUnits(int n, String unit) => '$n $unit remaining';

  @override
  String extraUnits(int n, String unit) => '$n $unit extra';

  @override
  String stockLevelPercent(int n) => '$n% level';

  // ── Manual Add ────────────────────────────────────
  @override
  String get manualAddTitle => 'Manual Add';
  @override
  String get doneBtn => 'Done';
  @override
  String setQuantityFor(String type, String name) =>
      'Set $type Quantity:\n$name';
  @override
  String get enterAmount => 'Enter amount...';

  // ── OCR Scan Result ────────────────────────────────
  @override
  String get reviewScanResults => 'Review Scan Results';
  @override
  String get scannedImage => 'Scanned Image';
  @override
  String get noMedicineDetectedTryAgain =>
      'No medicine names detected. Try again.';
  @override
  String get selectedForImport => 'Selected for Import:';

  // ── Subscription ──────────────────────────────────
  @override
  String get elevatePharmacy => 'Elevate Your Pharmacy';
  @override
  String get choosePlanDesc =>
      'Choose the plan that fits your business needs. Switch or cancel anytime.';
  @override
  String get monthlyBilling => 'Monthly';
  @override
  String get yearlySave20 => 'Yearly (Save 20%)';
  @override
  @override
  String get haveCouponCode => 'Have a coupon code?';
  @override
  String get enterCodeHere => 'Enter code here...';
  @override
  String get couponApplied => 'Coupon applied successfully!';
  @override
  String get invalidCoupon => 'Invalid coupon code.';
  @override
  String get couponExpired => 'Coupon has expired.';
  @override
  String get couponLimitReached => 'Coupon usage limit reached.';
  @override
  String discountAmount(String amount) => 'Discount: ৳$amount';
  @override
  String freeDaysAdded(int days) => '$days free days will be added';
  @override
  String get getStartedSubscription => 'Get Started with Subscription';
  @override
  String get epsSafePayment => 'EPS Safe Payment';
  @override
  String itemsDetected(int n) => '$n item${n == 1 ? '' : 's'} detected';
  @override
  String get retake => 'Retake';
  @override
  String get scannedText => 'SCANNED TEXT';
  @override
  String matchPercent(int n) => '$n% match';
  @override
  String get exactMatchFound => 'EXACT MATCH FOUND';
  @override
  String get multipleMatchesSelect => 'MULTIPLE MATCHES — PLEASE SELECT:';
  @override
  String get selectCorrectProduct => '— Select Correct Product —';
  @override
  String get statusAccepted => 'ACCEPTED';
  @override
  String get statusRejected => 'REJECTED';
  @override
  String get statusPending => 'PENDING';
  @override
  String get undoReject => 'Undo Reject';
  @override
  String get reject => 'Reject';
  @override
  String get accept => 'Accept';
  @override
  String get selectProductFirst => 'Select a product from the dropdown first.';
  @override
  String productsAddedToCart(int n) => '$n product(s) added to cart.';
  @override
  String get noMatchesFound => 'No matches found';
  @override
  String get tryRetakingPhoto => 'Try retaking the photo with better lighting.';
  @override
  String get commitValidItems => 'Commit Valid Items';
  @override
  String get resolveSelectionsFirst => 'Resolve Selections First';

  // ── Missing Home / Drawer Strings ─────────────────
  @override
  String get hide => 'Hide';
  @override
  String get manual => 'Manual';
  @override
  String get ocr => 'OCR';
  @override
  String get tapToScanOcr => 'Tap Scanner';
  @override
  String get tapToScanOcrHelper => 'OCR armed. Tap scanner to read strip.';
  @override
  String get scannerTapToReadStrip => 'OCR ready - tap scanner to read strip';
  @override
  String get ocrCaptureFailed => 'Could not capture scanner frame. Try again.';
  @override
  String get voice => 'Voice';
  @override
  String get scannerActiveExpand => 'Scanner active — tap to expand';
  @override
  String get scannerPausedExpand => 'Scanner paused — tap to expand';
  @override
  String get cameraPaused => 'Camera Paused';
  @override
  String get tapToResume => 'Tap to resume';
  @override
  String get tapScannerToPauseResume => 'Tap scanner to pause/resume';
  @override
  String get scannerPausedTapToResume => 'Scanner paused — tap to resume';
  @override
  String get collapse => 'Collapse';
  @override
  String get cartIsEmpty => 'Cart is empty';
  @override
  String get scanItemToBegin => 'Scan an item to begin';
  @override
  String get totalPayable => 'TOTAL PAYABLE';
  @override
  String get checkout => 'Checkout';
  @override
  String get checkoutFailed => 'Checkout failed. Please try again.';
  @override
  String get itemWord => 'item';
  @override
  String get itemsWord => 'items';
  @override
  String get navHome => 'Home';
  @override
  String get navManagement => 'MANAGEMENT';
  @override
  String get navInventory => 'INVENTORY';
  @override
  String get driveBackupNotSynced => 'Drive Backup: Not synced';
  @override
  String get driveBackupSyncing => 'Drive Backup: Syncing...';
  @override
  String get driveBackupFailed => 'Drive Backup: Failed';
  @override
  String syncedAt(String time) => 'Synced: ';
}
