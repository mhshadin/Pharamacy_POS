import 'app_strings.dart';

class AppStringsBn implements AppStrings {
  // ── Navigation & App Info ──────────────────────────
  @override String get navDashboard => 'ড্যাশবোর্ড';
  @override String get navAddProduct => 'ওষুধ যুক্ত করুন';
  @override String get navReturns => 'রিটার্ন';
  @override String get navSalesReport => 'বিক্রয় রিপোর্ট';
  @override String get navExpiringSoon => 'মিয়াদোত্তীর্ণ ওষুধ';
  @override String get navLowStock => 'কম স্টক';
  @override String get navProductList => 'ওষুধের তালিকা';
  @override String get navTopProducts => 'শীর্ষ পণ্য';
  @override String get navSettings => 'সেটিংস';
  @override String get navProfile => 'প্রোফাইল';
  @override String get navNotifications => 'নোটিফিকেশন';
  @override String get navBackToPos => 'পিওএস-এ ফিরে যান';
  @override String get appName => 'ফার্মেসি পিওএস';
  @override String get posTitle => 'ফার্মাপস';
  @override String get adminPortal => 'অ্যাডমিন পোর্টাল';
  @override String get backToPos => 'পিওএস-এ ফিরে যান';

  // ── POS / Home Screen ──────────────────────────────
  @override String get saleComplete => 'বিক্রয় সম্পন্ন';
  @override String get clearCart => 'কার্ট মুছবেন?';
  @override String get clearCartConfirm => 'আপনি কি নিশ্চিত যে আপনি কার্টটি খালি করতে চান?';
  @override String get newSale => 'নতুন বিক্রয়';
  @override String get cancelBtn => 'বাতিল';
  @override String get yesClr => 'হ্যাঁ, মুছুন';
  @override String get addedToCart => 'কার্টে যোগ করা হয়েছে';
  @override String get noMatchVoice => 'কোনো মিল পাওয়া যায়নি – নাম সংশোধন করে সার্চ আইকন চাপুন।';
  @override String get barcodeNotFound => 'বারকোডের জন্য কোনো ওষুধ পাওয়া যায়নি';
  @override String get readingStrip => 'পাতা পড়া হচ্ছে...';
  @override String get noMedicineDetected => 'কোনো ওষুধের নাম শনাক্ত করা যায়নি। আবার চেষ্টা করুন।';
  @override String get successCharged => 'সফলভাবে পেমেন্ট নেওয়া হয়েছে';
  @override String get successfullyCharged => 'সফলভাবে পেমেন্ট নেওয়া হয়েছে';
  @override String get listening => 'শুনছি...';
  @override String get searchHint => 'ওষুধের নাম বা জেনেটিক দিয়ে খুঁজুন...';
  @override String get voiceSearchHint => 'সংশোধন করে সার্চ করুন...';
  @override String get menuTooltip => 'মেনু';
  @override String get searchTooltip => 'ওষুধ খুঁজুন';
  @override String get closeSearchTooltip => 'সার্চ বন্ধ করুন';
  @override String get alertsTooltip => 'সতর্কবার্তা';
  @override String get searchBtnTooltip => 'খুঁজুন';
  @override String get discardBtnTooltip => 'বাতিল';
  @override String get saleCompleteInvoice => 'বিক্রয় সম্পন্ন! ইনভয়েস:';

  // ── Admin Dashboard ────────────────────────────────
  @override String get overview => 'সারসংক্ষেপ';
  @override String get todaysSales => 'আজকের বিক্রি';
  @override String get todaySales => 'আজকের বিক্রি';
  @override String get totalOrders => 'মোট অর্ডার';
  @override String get lowStock => 'কম স্টক';
  @override String get expiringSoon => 'মিয়াদোত্তীর্ণ ওষুধ';
  @override String get criticalInventory => 'জরুরি ইনভেন্টরি';
  @override String get allStockGood => 'সব স্টোক ঠিক আছে! 🎉';
  @override String get noLowStockExpiring => 'কোনো কম স্টক বা মিয়াদোত্তীর্ণ ওষুধ নেই।';
  @override String get recentTransactions => 'সাম্প্রতিক লেনদেন';
  @override String get lowStockBadge => 'কম স্টক';
  @override String get expiringSoonBadge => 'মিয়াদোত্তীর্ণ ওষুধ';
  @override String get unknownExpiry => 'অজানা মিয়াদ';
  @override String get expiresPrefix => 'মিয়াদ শেষ: ';
  @override String lastUpdated(String dateTime) => 'সর্বশেষ আপডেট: $dateTime';
  @override String get units => 'ইউনিট';
  @override String get pcsSuffix => 'পিস';

  // ── Product Management ─────────────────────────────
  @override String get productList => 'ওষুধের তালিকা';
  @override String get searchProducts => 'ওষুধ খুঁজুন';
  @override String get editBtn => 'সম্পাদনা';
  @override String get restockBtn => 'রিস্টক';
  @override String get noProductsFound => 'কোনো ওষুধ পাওয়া যায়নি';
  @override String get deleteProduct => 'ওষুধ মুছবেন?';
  @override String get deleteProductConfirm => 'আপনি কি নিশ্চিত যে আপনি এই ওষুধটি মুছতে চান?';
  @override String get deleteBtn => 'মুছে ফেলুন';
  @override String get productDeleted => 'ওষুধটি সফলভাবে মুছে ফেলা হয়েছে';
  @override String get addProduct => 'ওষুধ যুক্ত করুন';
  @override String get editProduct => 'ওষুধ সম্পাদনা';
  @override String get productName => 'ওষুধের নাম';
  @override String get genericName => 'জেনেরিক নাম';
  @override String get category => 'ধরণ';
  @override String get pricePerPc => 'প্রতি পিস দাম';
  @override String get pricePerStrip => 'প্রতি পাতা দাম';
  @override String get pcsPerStrip => 'প্রতি পাতায় পিস';
  @override String get stockBoxes => 'স্টক বক্স';
  @override String get pcsPerBox => 'প্রতি বক্সে পিস';
  @override String get minStockLevel => 'সর্বনিম্ন স্টক লেভেল';
  @override String get expiryDate => 'মিয়াদ শেষ হবার তারিখ';
  @override String get supplierName => 'সরবরাহকারীর নাম';
  @override String get supplierPhone => 'সরবরাহকারীর ফোন';
  @override String get saveProduct => 'ওষুধ সংরক্ষণ করুন';
  @override String get productSaved => 'ওষুধটি সফলভাবে সংরক্ষিত হয়েছে';
  @override String get productUpdated => 'ওষুধটি সফলভাবে আপডেট করা হয়েছে';
  @override String get requiredField => 'প্রয়োজনীয় তথ্য';
  @override String get restock => 'রিস্টক';
  @override String get restockTitle => 'ওষুধ রিস্টক করুন';
  @override String get boxesToAdd => 'যোগ করার জন্য বক্স';
  @override String get confirmRestock => 'রিস্টক নিশ্চিত করুন';
  @override String get restockSuccess => 'রিস্টক সফল হয়েছে';
  @override String get stockStrips => 'পাতা';
  @override String get stockPcs => 'পিস';
  @override String get pcsRemaining => 'পিস অবশিষ্ট';
  @override String get minStock => 'সর্বনিম্ন';

  // ── Filtering & Sorting ────────────────────────────
  @override String get filterByCompany => 'কোম্পানি অনুযায়ী ফিল্টার';
  @override String get filterByGeneric => 'জেনেরিক অনুযায়ী ফিল্টার';
  @override String get filterByType => 'ধরণ অনুযায়ী ফিল্টার';
  @override String get searchCompanies => 'কোম্পানি খুঁজুন...';
  @override String get searchGenerics => 'জেনেরিক খুঁজুন...';
  @override String get clearAll => 'সব মুছুন';
  @override String get applyBtn => 'প্রয়োগ করুন';
  @override String get deleteProducts => 'পণ্য মুছুন';
  @override String get deleteConfirm => 'আপনি কি নিশ্চিত যে আপনি এই পণ্যগুলো মুছতে চান?';
  @override String get sortBtn => 'সাজান';
  @override String get sortUrgency => 'জরুরি ভিত্তিতে';
  @override String get sortExpiry => 'মিয়াদ: নিকটতম আগে';
  @override String get sortNameAZ => 'নাম: অ → হ';
  @override String get sortPriceHighLow => 'দাম: বেশি → কম';
  @override String get sortPriceLowHigh => 'দাম: কম → বেশি';
  @override String get noCompaniesFound => 'কোনো কোম্পানি পাওয়া যায়নি';
  @override String get noGenericsFound => 'কোনো জেনেরিক পাওয়া যায়নি';
  @override String get selectItems => 'আইটেম নির্বাচন করুন';
  @override String get cancelSelection => 'নির্বাচন বাতিল';
  @override String get deleteSelected => 'নির্বাচিতগুলো মুছুন';
  @override String get sortNewest => 'নতুন আগে';
  @override String get sortOldest => 'পুরানো আগে';
  @override String get sortHighToLow => 'টাকা: বেশি থেকে কম';
  @override String get sortLowToHigh => 'টাকা: কম থেকে বেশি';

  // ── Settings & Auth ───────────────────────────────
  @override String get signInToStart => 'বিক্রয় শুরু করতে সাইন ইন করুন';
  @override String get emailLabel => 'ইমেল';
  @override String get passwordLabel => 'পাসওয়ার্ড';
  @override String get signInBtn => 'সাইন ইন';
  @override String get continueWithGoogle => 'গুগল দিয়ে প্রবেশ করুন';
  @override String get orCreateAccount => 'অথবা নতুন অ্যাকাউন্ট তৈরি করুন';
  @override String get createPharmacyAccount => 'ফার্মেসি অ্যাকাউন্ট তৈরি করুন';
  @override String get createAccountBtn => 'অ্যাকাউন্ট তৈরি করুন';
  @override String get fullNameLabel => 'আপনার পূর্ণ নাম';
  @override String get pharmacyNameLabel => 'ফার্মেসি / ব্যবসার নাম';
  @override String get passwordMinChars => 'পাসওয়ার্ড (কমপক্ষে ৮ অক্ষর)';
  @override String get confirmPasswordLabel => 'পাসওয়ার্ড নিশ্চিত করুন';
  @override String get validationEnterEmail => 'অনুগ্রহ করে আপনার ইমেল দিন';
  @override String get validationValidEmail => 'অনুগ্রহ করে সঠিক ইমেল দিন';
  @override String get validationEnterPassword => 'অনুগ্রহ করে পাসওয়ার্ড দিন';
  @override String get validationPasswordMin => 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে';
  @override String get validationEnterName => 'অনুগ্রহ করে আপনার নাম দিন';
  @override String get validationEnterBusiness => 'অনুগ্রহ করে আপনার ব্যবসা বা ফার্মেসির নাম দিন';
  @override String get validationConfirmPassword => 'অনুগ্রহ করে পাসওয়ার্ডটি আবার দিন';
  @override String get validationPasswordsNoMatch => 'পাসওয়ার্ড দুটি মিলছে না';
  @override String get loginFailed => 'লগইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override String get registrationFailed => 'নিবন্ধন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override String get googleSignInFailed => 'গুগল সাইন-ইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override String get inventoryAlerts => 'ইনভেন্টরি অ্যালার্ট';
  @override String get lowStockThreshold => 'লো স্টক থ্রেশহোল্ড (বক্স)';
  @override String get lowStockThresholdHelper => 'বক্সের সংখ্যা অনুযায়ী ডিফল্ট সতর্কবার্তা। আলাদা ওষুধের জন্য এটি পরিবর্তন করা যেতে পারে।';
  @override String get defaultBoxesToOrder => 'ডিফল্ট অর্ডার বক্স সংখ্যা';
  @override String get defaultBoxesHelper => 'কম স্টক বা মিয়াদোত্তীর্ণ তালিকা থেকে অর্ডার লিস্ট তৈরির সময় এটি কাজে লাগে।';
  @override String get expiringSoonWindow => 'মিয়াদোত্তীর্ণ উইন্ডো (দিন)';
  @override String get expiringSoonWindowHelper => 'এত দিনের মধ্যে মিয়াদ শেষ হবে এমন ওষুধগুলো এই তালিকায় দেখাবে।';
  @override String get moderateExpiry => 'মাঝারি মিয়াদ (দিন, হলুদ)';
  @override String get moderateExpiryHelper => 'হলুদ হাইলাইট: এত দিনের মধ্যে মিয়াদ শেষ হবে (কিন্তু জরুরি সময় পার করার পর)।';
  @override String get criticalExpiry => 'জরুরি মিয়াদ (দিন, লাল)';
  @override String get criticalExpiryHelper => 'লাল হাইলাইট: এত দিনের মধ্যে মিয়াদ শেষ হবে (এবং মেয়াদ উত্তীর্ণ ওষুধ)।';
  @override String get defaultExpiryDelay => 'ডিফল্ট মিয়াদ বিলম্ব (মাস)';
  @override String get defaultExpiryDelayHelper => 'ওষুধ যোগ করার সময় মিয়াদ শেষ হবার তারিখটি আজ থেকে কত মাস পরের হবে তা নির্ধারণ করে।';
  @override String get showSupplierInfo => 'ওষুধ যোগ করার সময় সরবরাহকারীর তথ্য দেখান';
  @override String get showSupplierInfoHelper => 'সরবরাহকারীর নাম এবং ফোন নম্বর সংরক্ষণ করতে এটি চালু করুন।';
  @override String get saveSettings => 'সেটিংস সংরক্ষণ করুন';
  @override String get settingsSaved => 'সেটিংস সফলভাবে সংরক্ষিত হয়েছে';
  @override String get expiryOrderError => 'মিয়াদের দিনগুলো ক্রমানুসারে হতে হবে: জরুরি (লাল) ≤ মাঝারি (হলুদ) ≤ মিয়াদোত্তীর্ণ উইন্ডো।';
  @override String get databaseBackup => 'ডাটাবেস ব্যাকআপ';
  @override String get googleDriveIntegration => 'গুগল ড্রাইভ ইন্টিগ্রেশন';
  @override String get googleDriveDesc => 'আপনার ডাটাবেস নিরাপদে গুগল ড্রাইভে ব্যাকআপ রাখুন।';
  @override String get notSyncedYet => 'এখনও সিঙ্ক করা হয়নি';
  @override String get syncingNow => 'সিঙ্ক করা হচ্ছে...';
  @override String get syncFailed => 'সিঙ্ক ব্যর্থ হয়েছে';
  @override String get lastSync => 'সর্বশেষ সিঙ্ক';
  @override String get missingDriveScope => 'গুগল ড্রাইভ ব্যবহারের অনুমতি নেই। লগআউট করে আবার লগইন করুন।';
  @override String get ensureSignedIn => 'নিশ্চিত করুন যে আপনি লগইন করেছেন এবং ইন্টারনেট সচল আছে।';
  @override String get syncNow => 'এখনই সিঙ্ক করুন';
  @override String get phoneStorageBackup => 'ফোন স্টোরেজ ব্যাকআপ';
  @override String get offlineBackupImport => 'অফলাইন ব্যাকআপ ও ইম্পোর্ট';
  @override String get offlineBackupDesc => 'আপনার ফোনে ব্যাকআপ ফাইল এক্সপোর্ট করুন বা বিদ্যমান .db ফাইল থেকে ইম্পোর্ট করুন।';
  @override String get exportNow => 'এখনই এক্সপোর্ট করুন';
  @override String get importDb => 'ইম্পোর্ট ডিবি';
  @override String get exportedSuccess => 'ডাটাবেসটি ফোনের মেমোরিতে এক্সপোর্ট করা হয়েছে';
  @override String get importDatabase => 'ডাটাবেস ইম্পোর্ট করবেন?';
  @override String get importDatabaseWarning => 'এটি আপনার বর্তমান সব তথ্য মুছে ফেলবে এবং ব্যাকআপ ডাটা যোগ করবে। এটি ফেরত পাওয়া সম্ভব নয়।';
  @override String get importReplace => 'ইম্পোর্ট এবং পরিবর্তন';
  @override String get importSuccess => 'ইম্পোর্ট সফল হয়েছে!';
  @override String get importFailed => 'ইম্পোর্ট ব্যর্থ হয়েছে';
  @override String get medicineCategories => 'ওষুধের ধরণ';
  @override String get medicineCategoriesDesc => 'ট্যাবলেট, সিরাপ ইত্যাদি ধরণগুলো পরিচালনা করুন।';
  @override String get addNewType => 'নতুন ধরণ যোগ করুন (যেমন: ইনহেলার)';
  @override String get removeCategory => 'ধরণ মুছবেন?';
  @override String get removeCategoryConfirm => 'আপনি কি নিশ্চিত যে আপনি এটি মুছতে চান';
  @override String get removeCategoryWarning => 'এই ধরণের বর্তমান ওষুধগুলো মুছবে না, তবে পরবর্তীতে এডিটর সময় পরিবর্তন করতে হতে পারে।';
  @override String get removeBtn => 'মুছুন';
  @override String get languageSetting => 'ভাষা';
  @override String get languageEnglish => 'English';
  @override String get languageBangla => 'বাংলা';
  @override String get logout => 'লগআউট';
  @override String get logoutConfirm => 'আপনি কি নিশ্চিত যে আপনি লগআউট করতে চান?';
  @override String get notifications => 'নোটিফিকেশন';

  // ── Reports & Others ──────────────────────────────
  @override String get returnsTitle => 'রিটার্ন';
  @override String get filterReturns => 'রিটার্ন ফিল্টার';
  @override String get dateRange => 'তারিখের রেঞ্জ';
  @override String get amountRange => 'টাকার রেঞ্জ (৳)';
  @override String get timeRange => 'সময়ের রেঞ্জ';
  @override String get anyTime => 'যেকোনো সময়';
  @override String get clearTime => 'সময় মুছুন';
  @override String get returnItems => 'আইটেম রিটার্ন করুন';
  @override String get confirmReturn => 'রিটার্ন নিশ্চিত করুন';
  @override String get noItemsInvoice => 'এই ইনভয়েস থেকে কোনো আইটেম পাওয়া যায়নি।';
  @override String get allItemsReturned => 'এই ইনভয়েসের সব আইটেম আগে ফেরত দেওয়া হয়েছে।';
  @override String get someProductsSkipped => 'কিছু পণ্য বাদ দেওয়া হয়েছে';
  @override String get couldNotFindProducts => 'ওষুধ খুঁজে পাওয়া যায়নি';
  @override String get returnItemsFor => 'আইটেম রিটার্ন করুন এর জন্য:';
  @override String get strips => 'পাতা';
  @override String get pcs => 'পিস';
  @override String get maxReturnable => 'সর্বোচ্চ ফেরতযোগ্য';
  @override String get selected => 'নির্বাচিত';
  @override String get changeBtn => 'পরিবর্তন';
  @override String get salesReport => 'বিক্রয় রিপোর্ট';
  @override String get totalRevenue => 'মোট আয়';
  @override String get totalTransactions => 'মোট লেনদেন';
  @override String get topProduct => 'শীর্ষ পণ্য';
  @override String get noSalesData => 'এই সময়ের জন্য কোনো বিক্রির তথ্য নেই';
  @override String get exportPdf => 'পিডিএফ এক্সপোর্ট';
  @override String get exportCsv => 'সিএসভি এক্সপোর্ট';
  @override String get exportSuccess => 'রিপোর্ট সফলভাবে এক্সপোর্ট করা হয়েছে';
  @override String get exportFailed => 'রিপোর্ট এক্সপোর্ট করতে সমস্যা হয়েছে';
  @override String get today => 'আজকের';
  @override String get thisWeek => 'এই সপ্তাহের';
  @override String get thisMonth => 'এই মাসের';
  @override String get last3Months => 'গত ৩ মাস';
  @override String exportError(String error) => 'রিপোর্ট এক্সপোর্টে সমস্যা: $error';
  @override String get reportSaved => 'রিপোর্ট সফলভাবে সংরক্ষিত হয়েছে!';
  @override String get reportFailed => 'রিপোর্ট সংরক্ষণ করা যায়নি।';
  @override String get transactionHistory => 'লেনদেনের ইতিহাস';
  @override String recordsCount(int count) => '$countটি রেকর্ড';
  @override String get orders => 'অর্ডার';
  @override String get itemsSold => 'বিক্রিত ওষুধ';
  @override String get noTransactionsFound => 'কোনো লেনদেন পাওয়া যায়নি';
  @override String get tryAnotherFilter => 'অন্য কোনো তারিখ বা ফিল্টার চেষ্টা করুন';
  @override String get revenueTrend => 'রাজস্ব প্রবণতা';
  @override String get period => 'সময়কাল';
  @override String get customRange => 'কাস্টম রেঞ্জ';
  @override String get weekly => 'সাপ্তাহিক';
  @override String get monthly => 'মাসিক';
  @override String get yearly => 'বার্ষিক';
  @override String get newestFirst => 'নতুন আগে';
  @override String get oldestFirst => 'পুরানো আগে';
  @override String get amountHigh => 'টাকা (বেশি)';
  @override String get amountLow => 'টাকা (কম)';
  @override String get productAZ => 'ওষুধ A-Z';
  @override String get mon => 'সোম'; @override String get tue => 'মঙ্গল'; @override String get wed => 'বুধ';
  @override String get thu => 'বৃহস্পতি'; @override String get fri => 'শুক্র'; @override String get sat => 'শনি'; @override String get sun => 'রবি';
  @override String get jan => 'জানু'; @override String get feb => 'ফেব্রু'; @override String get mar => 'মার্চ';
  @override String get apr => 'এপ্রিল'; @override String get may => 'মে'; @override String get jun => 'জুন';
  @override String get jul => 'জুলাই'; @override String get aug => 'আগস্ট'; @override String get sep => 'সেপ্টেম্বর'; @override String get oct => 'অক্টোবর'; @override String get nov => 'নভেম্বর'; @override String get dec => 'ডিসেম্বর';
  @override String get others => 'অন্যান্য';
  @override String get expiringSoonTitle => 'দ্রুত মেয়াদোত্তীর্ণ হবে';
  @override String get lowStockTitle => 'কম স্টকের ওষুধ';
  @override String get exportOrderList => 'অর্ডার লিস্ট এক্সপোর্ট';
  @override String get noExpiringSoon => 'নিকট ভবিষ্যতে মিয়াদ শেষ হবে এমন কোনো ওষুধ নেই';
  @override String get noLowStock => 'স্টক কম এমন কোনো ওষুধ নেই';
  @override String get remainingPcs => 'পিস অবশিষ্ট';
  @override String get boxesSuffix => 'বক্স';
  @override String get stripsSuffix => 'পাতা';
  @override String get notificationsTitle => 'নোটিফিকেশন';
  @override String get noNotifications => 'কোনো নোটিফিকেশন নেই';
  @override String get markAllRead => 'সব পড়া হয়েছে হিসেবে চিহ্নিত করুন';
  @override String get profileTitle => 'প্রোফাইল';
  @override String get signOut => 'লগআউট';
  @override String get signOutConfirm => 'আপনি কি নিশ্চিত যে আপনি লগআউট করতে চান?';
  @override String get accountInfo => 'অ্যাকাউন্ট তথ্য';
  @override String get changePassword => 'পাসওয়ার্ড পরিবর্তন';
  @override String get currentPassword => 'বর্তমান পাসওয়ার্ড';
  @override String get newPassword => 'নতুন পাসওয়ার্ড';
  @override String get updatePassword => 'পাসওয়ার্ড আপডেট করুন';
  @override String get passwordUpdated => 'পাসওয়ার্ড সফলভাবে আপডেট করা হয়েছে';
  @override String get subscriptionTitle => 'সাবস্ক্রিপশন';
  @override String get subscribeBtn => 'এখনই সাবস্ক্রাইব করুন';
  @override String get currentPlan => 'বর্তমান প্ল্যান';
  @override String get expiresOn => 'মিয়াদ শেষ হবে';
  @override String get trialExpired => 'ট্রায়াল শেষ';
  @override String get renewBtn => 'রিনিউ করুন';
  @override String get ocrScanResult => 'ওসিআর ফলাফল';
  @override String get addAllToCart => 'সব কার্টে যোগ করুন';
  @override String get confirmedItems => 'নিশ্চিত আইটেমসমূহ';
  @override String get generalInfo => 'সাধারণ তথ্য';
  @override String get packaging => 'প্যাকেজিং';
  @override String get pricing => 'মূল্য নির্ধারণ';
  @override String get inventory => 'ইনভেন্টরি';
  @override String get expiryBatch => 'মেয়াদ / ব্যাচ';
  @override String get supplierInfo => 'সরবরাহকারীর তথ্য';
  @override String get selectExpiryDate => 'অনুগ্রহ করে মেয়াদের তারিখ নির্বাচন করুন।';
  @override String get batchNumber => 'ব্যাচ নম্বর';
  @override String get barcodeLabel => 'বারকোড (ঐচ্ছিক)';
  @override String get scanBtn => 'স্ক্যান';
  @override String get stripsPerBox => 'বক্স প্রতি পাতা';
  @override String get failedToSaveProduct => 'পণ্য সংরক্ষণ করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।';
  @override String get noDate => 'কোনো তারিখ নেই';
  @override String get bulkImport => 'একসাথে পণ্য ইনপুট (CSV)';
  @override String get changeMedType => 'ওষুধের ধরন পরিবর্তন করুন';
  @override String get returns => 'ফেরত সমূহ';
  @override String get searchBtn => 'অনুসন্ধান';
  @override String get searchHelpText => 'ইনভয়েস নম্বর বা ওষুধের নাম দিয়ে খুঁজুন';
  @override String get noResults => 'কোনো ফলাফল পাওয়া যায়নি';
  @override String get fullyReturned => 'সম্পূর্ণ ফেরত দেওয়া হয়েছে';
  @override String get qtyLabel => 'পরিমাণ';
  @override String get retLabel => 'ফেরত';
  @override String get batchLabel => 'ব্যাচ';
  @override String get returnsProcessed => 'ফেরত সফলভাবে সম্পন্ন হয়েছে!';
  @override String get sortBy => 'সর্ট করুন';
  @override String get sortAmountHigh => 'মূল্য: বেশি থেকে কম';
  @override String get sortAmountLow => 'মূল্য: কম থেকে বেশি';
  @override String get filters => 'ফিল্টারসমূহ';

  // ── Common / Shared ───────────────────────────────
  @override String get loading => 'লোড হচ্ছে...';
  @override String get error => 'সমস্যা';
  @override String get success => 'সফল';
  @override String get tryAgain => 'আবার চেষ্টা করুন';
  @override String get toLabel => 'থেকে';
  @override String get close => 'বন্ধ করুন';
  @override String get open => 'খুলুন';
  @override String get confirm => 'নিশ্চিত';
  @override String get apply => 'প্রয়োগ';
  @override String get search => 'খুঁজুন';
  @override String get filter => 'ফিল্টার';
  @override String get sort => 'সাজান';
  @override String get noResultsFound => 'কোনো ফলাফল পাওয়া যায়নি';
  @override String get boxes => 'বক্স';
  @override String get minAmount => 'সর্বনিম্ন ৳';
  @override String get maxAmount => 'সর্বোচ্চ ৳';

  @override String get deselectAll => 'সব বাতিল করুন';
  @override String get selectAll => 'সব নির্বাচন করুন';
  @override
  String selectedCount(int count) => '$count টি নির্বাচন করা হয়েছে';

  @override
  String sortOption(String option) {
    switch (option) {
      case 'Urgency (Recommended)':
        return 'জরুরী (প্রস্তাবিত)';
      case 'Expiry: Soonest First':
        return 'মেয়াদ: আগে শেষ হবে';
      case 'Name: A → Z':
        return 'নাম: অ → ঔ';
      case 'Price: High → Low':
        return 'দাম: বেশি → কম';
      case 'Price: Low → High':
        return 'দাম: কম → বেশি';
      default:
        return option;
    }
  }
  @override String get productListEmpty => 'আপনার ওষুধের তালিকা বর্তমানে খালি।';
  @override String get noProductsMatchCriteria => 'আপনার সার্চ বা ফিল্টার অনুযায়ী কোনো ওষুধ পাওয়া যায়নি।';
  @override String get clearAllFilters => 'সব ফিল্টার মুছুন';
  @override String get inStock => 'স্টকে আছে';
  @override String get pieces => 'পিস';
  @override String get stripPrice => 'পাতা ৳';
  @override String get edit => 'সম্পাদনা';
  @override String get cancel => 'বাতিল';
  @override String get delete => 'মুছুন';
  @override
  String deleteProductsConfirmation(int count) => 'আপনি কি নিশ্চিত যে আপনি $count টি পণ্য মুছে ফেলতে চান?';

  @override
  String get deleteSelectedTooltip => 'নির্বাচিতগুলো মুছুন';
  @override String get taka => 'টাকা';
  @override String get companyName => 'কোম্পানি নাম';
  @override String get scan => 'স্ক্যান';
  @override String get exp => 'মেয়াদ';
  @override String get syrupHint => 'যেমন: ১০০ মিলি প্রতি বোতল';
  @override String get tube => 'টিউব';
  @override String get vial => 'ভায়াল';
  @override String get bottle => 'বোতল';
  @override String get sachet => 'স্যাসেট';
  @override String get inhaler => 'ইনহেলার';
  @override String get patch => 'প্যাচ';
  @override String get unit => 'ইউনিট';
  @override String get ml => 'মিলি';
  @override String get grams => 'গ্রাম';
  @override String get price => 'মূল্য';
  @override String get invoicePrefix => 'ইনভয়েস:';
  @override String get onePcSuffix => ' (১ পিস)';
  @override String voiceError(String error) => 'ভয়েস সমস্যা: $error';
  @override String ocrError(String error) => 'ওসিআর সমস্যা: $error';
  @override String get googleIdTokenError => 'গুগল আইডি টোকেন পাওয়া যায়নি।';
  @override String get createAccount => 'অ্যাকাউন্ট তৈরি করুন';
  @override String get unknownInvoice => 'অজানা ইনভয়েস';

  // --- Parameterized ---
  @override
  String productStockDetails(int boxes, int strips, int pcs, int min) =>
      '$boxes বক্স • $strips পাতা • $pcs পিস অবশিষ্ট (সর্বনিম্ন: $min)';

  @override
  String expiresDate(DateTime date) =>
      'মিয়াদ শেষ: ${date.day}/${date.month}/${date.year}';

  @override String productQuantity(String name, int quantity) => '$name × $quantity';
}
