import 'app_strings.dart';

class AppStringsBn implements AppStrings {
  // ── Navigation & App Info ──────────────────────────
  @override
  String get navDashboard => 'ড্যাশবোর্ড';
  @override
  String get navAddProduct => 'ওষুধ যুক্ত করুন';
  @override
  String get navReturns => 'রিটার্ন';
  @override
  String get navSalesReport => 'বিক্রয় রিপোর্ট';
  @override
  String get navExpiringSoon => 'মিয়াদোত্তীর্ণ ওষুধ';
  @override
  String get navLowStock => 'কম স্টক';
  @override
  String get navProductList => 'ওষুধের তালিকা';
  @override
  String get navTopProducts => 'শীর্ষ পণ্য';
  @override
  String get navSettings => 'সেটিংস';
  @override
  String get navProfile => 'প্রোফাইল';
  @override
  String get navNotifications => 'নোটিফিকেশন';
  @override
  String get navBackToPos => 'পিওএস-এ ফিরে যান';
  @override
  String get appName => 'ফার্মেসি পিওএস';
  @override
  String get posTitle => 'ফার্মাপস';
  @override
  String get adminPortal => 'অ্যাডমিন পোর্টাল';
  @override
  String get backToPos => 'পিওএস-এ ফিরে যান';
  @override
  String get adminSettings => 'অ্যাডমিন সেটিংস';
  @override
  String get general => 'সাধারণ';
  @override
  String get settingsTabAlarms => 'অ্যালার্ম';
  @override
  String get settingsTabSecurityData => 'নিরাপত্তা ও ডাটা';

  // ── POS / Home Screen ──────────────────────────────
  @override
  String get saleComplete => 'বিক্রয় সম্পন্ন';
  @override
  String get clearCart => 'কার্ট মুছবেন?';
  @override
  String get clearCartConfirm =>
      'আপনি কি নিশ্চিত যে আপনি কার্টটি খালি করতে চান?';
  @override
  String get newSale => 'নতুন বিক্রয়';
  @override
  String get cancelBtn => 'বাতিল';
  @override
  String get yesClr => 'হ্যাঁ, মুছুন';
  @override
  String get addedToCart => 'কার্টে যোগ করা হয়েছে';
  @override
  String get noMatchVoice =>
      'কোনো মিল পাওয়া যায়নি – নাম সংশোধন করে সার্চ আইকন চাপুন।';
  @override
  String get barcodeNotFound => 'বারকোডের জন্য কোনো ওষুধ পাওয়া যায়নি';
  @override
  String get readingStrip => 'পাতা পড়া হচ্ছে...';
  @override
  String get noMedicineDetected =>
      'কোনো ওষুধের নাম শনাক্ত করা যায়নি। আবার চেষ্টা করুন।';
  @override
  String get successCharged => 'সফলভাবে পেমেন্ট নেওয়া হয়েছে';
  @override
  String get successfullyCharged => 'সফলভাবে পেমেন্ট নেওয়া হয়েছে';
  @override
  String get listening => 'শুনছি...';
  @override
  String get searchHint => 'ওষুধের নাম বা জেনেটিক দিয়ে খুঁজুন...';
  @override
  String get voiceSearchHint => 'সংশোধন করে সার্চ করুন...';
  @override
  String get menuTooltip => 'মেনু';
  @override
  String get searchTooltip => 'ওষুধ খুঁজুন';
  @override
  String get closeSearchTooltip => 'সার্চ বন্ধ করুন';
  @override
  String get alertsTooltip => 'সতর্কবার্তা';
  @override
  String get searchBtnTooltip => 'খুঁজুন';
  @override
  String get discardBtnTooltip => 'বাতিল';
  @override
  String get saleCompleteInvoice => 'বিক্রয় সম্পন্ন! ইনভয়েস:';

  // ── Admin Dashboard ────────────────────────────────
  @override
  String get overview => 'সারসংক্ষেপ';
  @override
  String get todaysSales => 'আজকের বিক্রি';
  @override
  String get todaySales => 'আজকের বিক্রি';
  @override
  String get totalOrders => 'মোট অর্ডার';
  @override
  String get lowStock => 'কম স্টক';
  @override
  String get expiringSoon => 'মিয়াদোত্তীর্ণ ওষুধ';
  @override
  String get criticalInventory => 'জরুরি ইনভেন্টরি';
  @override
  String get allStockGood => 'সব স্টোক ঠিক আছে! 🎉';
  @override
  String get noLowStockExpiring => 'কোনো কম স্টক বা মিয়াদোত্তীর্ণ ওষুধ নেই।';
  @override
  String get recentTransactions => 'সাম্প্রতিক লেনদেন';
  @override
  String get lowStockBadge => 'কম স্টক';
  @override
  String get expiringSoonBadge => 'মিয়াদোত্তীর্ণ ওষুধ';
  @override
  String get unknownExpiry => 'অজানা মিয়াদ';
  @override
  String get expiresPrefix => 'মিয়াদ শেষ: ';
  @override
  String lastUpdated(String dateTime) => 'সর্বশেষ আপডেট: $dateTime';
  @override
  String get units => 'ইউনিট';
  @override
  String get pcsSuffix => 'পিস';

  // ── Notifications ─────────────────────────────
  @override
  String lowStockSubtitle(int strips) =>
      'ওষুধের স্টক কম ($strips পাতা অবশিষ্ট)';
  @override
  String expiresOnDate(String date) => '$date তারিখে মিয়াদ শেষ হবে';
  @override
  String get notificationLowStockTitle => 'কম স্টক সতর্কতা ⚠️';
  @override
  String notificationLowStockBody(String productName, int stock) =>
      '$productName এর স্টক কমে গেছে ($stock বাকি)। দ্রুত রিস্টক করুন।';
  @override
  String get notificationExpiryTitle => 'মেয়াদ সতর্কতা ⌛';
  @override
  String notificationExpiryBody(String productName, String expiryDate) =>
      '$productName এর মেয়াদ $expiryDate তারিখে শেষ হবে। ইনভেন্টরি পরীক্ষা করুন।';
  @override
  String get alarmInventoryCheckTitle => '⏰ ইনভেন্টরি চেক রিমাইন্ডার';
  @override
  String get alarmInventoryCheckBody =>
      'কম স্টক ও মেয়াদোত্তীর্ণ ওষুধগুলো এখন পরীক্ষা করুন!';
  @override
  String get alarmStockReminderTitle => 'স্টক রিমাইন্ডার';
  @override
  String get alarmStockReminderBody => 'এখন আপনার ইনভেন্টরি পরীক্ষা করার সময়।';
  @override
  String get alarmStockExpiryReminderTitle => 'স্টক ও মেয়াদ রিমাইন্ডার';
  @override
  String get alarmStockExpiryReminderBody =>
      'কম স্টক বা মেয়াদোত্তীর্ণ ওষুধ আছে কি না দেখে নিন।';
  @override
  String get alarmDismiss => 'বন্ধ করুন';

  // ── Top Products ───────────────────────────────
  @override
  String get topProductsToday => 'আজ';
  @override
  String get topProductsWeek => 'সপ্তাহ';
  @override
  String get topProductsMonth => 'মাস';
  @override
  String get topProductsYear => 'বছর';
  @override
  String get topProductsAllTime => 'সর্বকাল';
  @override
  String get revenueLabel => 'মোট আয়';
  @override
  String boxesSoldSuffix(double n) => '$n বক্স বিক্রি হয়েছে';

  // ── Product Management ─────────────────────────────
  @override
  String get productList => 'ওষুধের তালিকা';
  @override
  String get searchProducts => 'ওষুধ খুঁজুন';
  @override
  String get editBtn => 'সম্পাদনা';
  @override
  String get restockBtn => 'রিস্টক';
  @override
  String get noProductsFound => 'কোনো ওষুধ পাওয়া যায়নি';
  @override
  String get deleteProduct => 'ওষুধ মুছবেন?';
  @override
  String get deleteProductConfirm =>
      'আপনি কি নিশ্চিত যে আপনি এই ওষুধটি মুছতে চান?';
  @override
  String get deleteBtn => 'মুছে ফেলুন';
  @override
  String get productDeleted => 'ওষুধটি সফলভাবে মুছে ফেলা হয়েছে';
  @override
  String get addProduct => 'ওষুধ যুক্ত করুন';
  @override
  String get editProduct => 'ওষুধ সম্পাদনা';
  @override
  String get productName => 'ওষুধের নাম';
  @override
  String get genericName => 'জেনেরিক নাম';
  @override
  String get category => 'ধরণ';
  @override
  String get pricePerPc => 'প্রতি পিস দাম';
  @override
  String get pricePerStrip => 'প্রতি পাতা দাম';
  @override
  String get pcsPerStrip => 'প্রতি পাতায় পিস';
  @override
  String get stockBoxes => 'স্টক বক্স';
  @override
  String get pcsPerBox => 'প্রতি বক্সে পিস';
  @override
  String get minStockLevel => 'সর্বনিম্ন স্টক লেভেল';
  @override
  String get expiryDate => 'মিয়াদ শেষ হবার তারিখ';
  @override
  String get powerLabel => 'পাওয়ার/শক্তি';
  @override
  String get powerHint => 'যেমন: ৫০০ মি.গ্রা.';
  @override
  String get supplierName => 'সরবরাহকারীর নাম';
  @override
  String get supplierPhone => 'সরবরাহকারীর ফোন';
  @override
  String get saveProduct => 'ওষুধ সংরক্ষণ করুন';
  @override
  String get productSaved => 'ওষুধটি সফলভাবে সংরক্ষিত হয়েছে';
  @override
  String get productUpdated => 'ওষুধটি সফলভাবে আপডেট করা হয়েছে';
  @override
  String get requiredField => 'প্রয়োজনীয় তথ্য';
  @override
  String get restock => 'রিস্টক';
  @override
  String get restockTitle => 'ওষুধ রিস্টক করুন';
  @override
  String get boxesToAdd => 'যোগ করার জন্য বক্স';
  @override
  String get confirmRestock => 'রিস্টক নিশ্চিত করুন';
  @override
  String get restockSuccess => 'রিস্টক সফল হয়েছে';
  @override
  String get stockStrips => 'পাতা';
  @override
  String get stockPcs => 'পিস';
  @override
  String get pcsRemaining => 'পিস অবশিষ্ট';
  @override
  String get minStock => 'সর্বনিম্ন';

  // ── Restock Screen ─────────────────────────────
  @override
  String get pleaseSelectExpiryDate =>
      'অনুগ্রহ করে মিয়াদের তারিখ নির্বাচন করুন।';
  @override
  String get enterBoxesOrStrips => 'যোগ করার জন্য বক্স বা পাতা লিখুন।';
  @override
  String get failedToAddStock =>
      'স্টক যোগ করতে ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override
  String currentStock(int boxes, int strips, int pcs) =>
      'বর্তমান স্টক: $boxes বক্স • $strips পাতা • $pcs পিস';
  @override
  String currentExpiry(String date) => 'বর্তমান মিয়াদ (ওষুধ): $date';
  @override
  String packagingInfo(int spb, int pps) =>
      'প্যাকেজিং: $spb পাতা/বক্স • $pps পিস/পাতা';
  @override
  String get batchAndExpiry => 'ব্যাচ ও মিয়াদ';
  @override
  String get quantityToAdd => 'যোগ করার পরিমাণ';
  @override
  String get batchNoOptional => 'ব্যাচ নং (ঐচ্ছিক)';
  @override
  String newBatchExp(String date) => 'নতুন ব্যাচের মিয়াদ: $date';
  @override
  String get selectExpiryForBatch => 'নতুন ব্যাচের জন্য মিয়াদ নির্বাচন করুন*';
  @override
  String get addingLabel => 'যোগ করা হচ্ছে…';
  @override
  String get addStock => 'স্টক যোগ করুন';

  // ── Buying Price & Profit ───────────────────
  @override
  String get buyingPriceSection => 'ক্রয় মূল্য (খরচ)';
  @override
  String get buyingPricePerPc => 'ক্রয় মূল্য / বক্স (৳)';
  @override
  String get buyingPriceHelper =>
      'শেষ ব্যাচের বক্স মূল্যের ভিত্তিতে পূরণ করা হয়েছে। মূল্য পরিবর্তন হলে আপডেট করুন।';
  @override
  String get sellingPricePerPc => 'বিক্রয় মূল্য / বক্স (৳)';
  @override
  String get sellingPriceHelper =>
      'ঐচ্ছিক। পণ্যের প্রতি বক্স বিক্রয় মূল্য আপডেট করতে চাইলে এখানে দিন।';
  @override
  String profitPreview(String amount, String margin, bool isLoss) => isLoss
      ? 'লোকসান: ৳$amount/স্ট্রিপ ($margin%)'
      : 'লাভ: ৳$amount/স্ট্রিপ ($margin% মার্জিন)';
  @override
  String get navProfitReport => 'লাভের রিপোর্ট';
  @override
  String get profitReport => 'লাভের রিপোর্ট';
  @override
  String get grossProfit => 'মোট লাভ';
  @override
  String get totalCost => 'মোট খরচ';
  @override
  String get profitMargin => 'লাভের হার';
  @override
  String get viewProfitReport => 'লাভের রিপোর্ট দেখুন';
  @override
  String get noCostData =>
      'কোন খরচের তথ্য নেই — রিস্টক করার সময় ক্রয় মূল্য সেট করুন';
  @override
  String get profitReportEmpty => 'এই সময়ের জন্য কোন বিক্রয়ের তথ্য নেই';
  @override
  String get productBreakdown => 'পণ্য ভিত্তিক বিবরণ';

  // ── Filtering & Sorting ────────────────────────────
  @override
  String get filterByCompany => 'কোম্পানি অনুযায়ী ফিল্টার';
  @override
  String get filterByGeneric => 'জেনেরিক অনুযায়ী ফিল্টার';
  @override
  String get filterByType => 'ধরণ অনুযায়ী ফিল্টার';
  @override
  String get filterByStockStatus => 'স্টক অবস্থা অনুযায়ী ফিল্টার';
  @override
  String get filterByExpiryUrgency => 'মেয়াদ শেষের জরুরিতা অনুযায়ী ফিল্টার';
  @override
  String get searchCompanies => 'কোম্পানি খুঁজুন...';
  @override
  String get searchGenerics => 'জেনেরিক খুঁজুন...';
  @override
  String get clearAll => 'সব মুছুন';
  @override
  String get applyBtn => 'প্রয়োগ করুন';
  @override
  String get deleteProducts => 'পণ্য মুছুন';
  @override
  String get deleteConfirm => 'আপনি কি নিশ্চিত যে আপনি এই পণ্যগুলো মুছতে চান?';
  @override
  String get sortBtn => 'সাজান';
  @override
  String get sortUrgency => 'জরুরি ভিত্তিতে';
  @override
  String get sortExpiry => 'মিয়াদ: নিকটতম আগে';
  @override
  String get sortNameAZ => 'নাম: অ → হ';
  @override
  String get sortPriceHighLow => 'দাম: বেশি → কম';
  @override
  String get sortPriceLowHigh => 'দাম: কম → বেশি';
  @override
  String get noCompaniesFound => 'কোনো কোম্পানি পাওয়া যায়নি';
  @override
  String get noGenericsFound => 'কোনো জেনেরিক পাওয়া যায়নি';
  @override
  String get selectItems => 'আইটেম নির্বাচন করুন';
  @override
  String get cancelSelection => 'নির্বাচন বাতিল';
  @override
  String get deleteSelected => 'নির্বাচিতগুলো মুছুন';
  @override
  String get sortNewest => 'নতুন আগে';
  @override
  String get sortOldest => 'পুরানো আগে';
  @override
  String get sortHighToLow => 'টাকা: বেশি থেকে কম';
  @override
  String get sortLowToHigh => 'টাকা: কম থেকে বেশি';

  // ── Settings & Auth ───────────────────────────────
  @override
  String get signInToStart => 'বিক্রয় শুরু করতে সাইন ইন করুন';
  @override
  String get emailLabel => 'ইমেল';
  @override
  String get passwordLabel => 'পাসওয়ার্ড';
  @override
  String get signInBtn => 'সাইন ইন';
  @override
  String get continueWithGoogle => 'গুগল দিয়ে প্রবেশ করুন';
  @override
  String get orCreateAccount => 'অথবা নতুন অ্যাকাউন্ট তৈরি করুন';
  @override
  String get createPharmacyAccount => 'ফার্মেসি অ্যাকাউন্ট তৈরি করুন';
  @override
  String get createAccountBtn => 'অ্যাকাউন্ট তৈরি করুন';
  @override
  String get fullNameLabel => 'আপনার পূর্ণ নাম';
  @override
  String get pharmacyNameLabel => 'ফার্মেসি / ব্যবসার নাম';
  @override
  String get passwordMinChars => 'পাসওয়ার্ড (কমপক্ষে ৮ অক্ষর)';
  @override
  String get confirmPasswordLabel => 'পাসওয়ার্ড নিশ্চিত করুন';
  @override
  String get validationEnterEmail => 'অনুগ্রহ করে আপনার ইমেল দিন';
  @override
  String get validationValidEmail => 'অনুগ্রহ করে সঠিক ইমেল দিন';
  @override
  String get validationEnterPassword => 'অনুগ্রহ করে পাসওয়ার্ড দিন';
  @override
  String get validationPasswordMin => 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে';
  @override
  String get validationEnterName => 'অনুগ্রহ করে আপনার নাম দিন';
  @override
  String get validationEnterBusiness =>
      'অনুগ্রহ করে আপনার ব্যবসা বা ফার্মেসির নাম দিন';
  @override
  String get validationConfirmPassword => 'অনুগ্রহ করে পাসওয়ার্ডটি আবার দিন';
  @override
  String get validationPasswordsNoMatch => 'পাসওয়ার্ড দুটি মিলছে না';
  @override
  String get loginFailed => 'লগইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override
  String get registrationFailed => 'নিবন্ধন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override
  String get googleSignInFailed =>
      'গুগল সাইন-ইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override
  String get inventoryAlerts => 'ইনভেন্টরি';
  @override
  String get lowStockThreshold => 'লো স্টক থ্রেশহোল্ড (বক্স)';
  @override
  String get lowStockThresholdHelper =>
      'বক্সের সংখ্যা অনুযায়ী ডিফল্ট সতর্কবার্তা। আলাদা ওষুধের জন্য এটি পরিবর্তন করা যেতে পারে।';
  @override
  String get defaultBoxesToOrder => 'ডিফল্ট অর্ডার বক্স সংখ্যা';
  @override
  String get defaultBoxesHelper =>
      'কম স্টক বা মিয়াদোত্তীর্ণ তালিকা থেকে অর্ডার লিস্ট তৈরির সময় এটি কাজে লাগে।';
  @override
  String get expiringSoonWindow => 'মিয়াদোত্তীর্ণ উইন্ডো (দিন)';
  @override
  String get expiringSoonWindowHelper =>
      'এত দিনের মধ্যে মিয়াদ শেষ হবে এমন ওষুধগুলো এই তালিকায় দেখাবে।';
  @override
  String get moderateExpiry => 'মাঝারি মিয়াদ (দিন, হলুদ)';
  @override
  String get moderateExpiryHelper =>
      'হলুদ হাইলাইট: এত দিনের মধ্যে মিয়াদ শেষ হবে (কিন্তু জরুরি সময় পার করার পর)।';
  @override
  String get criticalExpiry => 'জরুরি মিয়াদ (দিন, লাল)';
  @override
  String get criticalExpiryHelper =>
      'লাল হাইলাইট: এত দিনের মধ্যে মিয়াদ শেষ হবে (এবং মেয়াদ উত্তীর্ণ ওষুধ)।';
  @override
  String get defaultExpiryDelay => 'ডিফল্ট মিয়াদ বিলম্ব (মাস)';
  @override
  String get defaultExpiryDelayHelper =>
      'ওষুধ যোগ করার সময় মিয়াদ শেষ হবার তারিখটি আজ থেকে কত মাস পরের হবে তা নির্ধারণ করে।';
  @override
  String get showSupplierInfo => 'ওষুধ যোগ করার সময় সরবরাহকারীর তথ্য দেখান';
  @override
  String get showSupplierInfoHelper =>
      'সরবরাহকারীর নাম এবং ফোন নম্বর সংরক্ষণ করতে এটি চালু করুন।';
  @override
  String get addProductDefaultStepperMode =>
      'ওষুধ যোগ স্ক্রিনে ডিফল্টে স্টেপার মোড চালু রাখুন';
  @override
  String get addProductDefaultStepperModeHelper =>
      'চালু থাকলে ওষুধ যোগ স্ক্রিন ধাপে ধাপে (Stepper) মোডে খুলবে।';
  @override
  String get addProductStepperModeToggle => 'স্টেপার মোড';
  @override
  String get restockPricingCollapsedByDefault =>
      'রিস্টকে Pricing সেকশন ডিফল্টে বন্ধ রাখুন';
  @override
  String get restockPricingCollapsedByDefaultHelper =>
      'চালু থাকলে রিস্টক স্ক্রিনে Pricing সেকশন শুরুতে বন্ধ থাকবে।';
  @override
  String get saveSettings => 'সেটিংস সংরক্ষণ করুন';
  @override
  String get settingsSaved => 'সেটিংস সফলভাবে সংরক্ষিত হয়েছে';
  @override
  String get expiryOrderError =>
      'মিয়াদের দিনগুলো ক্রমানুসারে হতে হবে: জরুরি (লাল) ≤ মাঝারি (হলুদ) ≤ মিয়াদোত্তীর্ণ উইন্ডো।';
  @override
  String get databaseStorageLocation => 'ডাটাবেস সংরক্ষণের অবস্থান';
  @override
  String get databaseStorageLocationDesc =>
      'pharmacy.db কোথায় স্থায়ীভাবে থাকবে তা বেছে নিন। পরিবর্তন করলে বর্তমান ডাটা কপি হয়ে যাবে।';
  @override
  String get chooseDatabaseFolder => 'ফোল্ডার বেছে নিন';
  @override
  String get resetDatabaseLocation => 'ডিফল্ট অবস্থান ব্যবহার করুন';
  @override
  String get databaseLocationDefaultDownloads =>
      'ডাউনলোডস — Pharmacy POS (ডিফল্ট)';
  @override
  String get databaseLocationDefaultAppFolder =>
      'অ্যাপ ডাটা ফোল্ডার (ডিফল্ট)';
  @override
  String get databaseFolderPickerTitle => 'pharmacy.db এর জন্য ফোল্ডার বেছে নিন';
  @override
  String get databaseLocationUpdated => 'ডাটাবেসের অবস্থান আপডেট হয়েছে';
  @override
  String get databaseLocationUpdateFailed =>
      'ডাটাবেসের অবস্থান পরিবর্তন করা যায়নি';
  @override
  String get alreadyUsingDefaultDbLocation =>
      'ইতিমধ্যে ডিফল্ট সংরক্ষণ অবস্থান ব্যবহার করা হচ্ছে।';
  @override
  String get databaseBackup => 'ডাটাবেস ব্যাকআপ';
  @override
  String get googleDriveIntegration => 'গুগল ড্রাইভ ইন্টিগ্রেশন';
  @override
  String get googleDriveDesc =>
      'আপনার ডাটাবেস নিরাপদে গুগল ড্রাইভে ব্যাকআপ রাখুন।';
  @override
  String get notSyncedYet => 'এখনও সিঙ্ক করা হয়নি';
  @override
  String get syncingNow => 'সিঙ্ক করা হচ্ছে...';
  @override
  String get syncFailed => 'সিঙ্ক ব্যর্থ হয়েছে';
  @override
  String get lastSync => 'সর্বশেষ সিঙ্ক';
  @override
  String get missingDriveScope =>
      'গুগল ড্রাইভ ব্যবহারের অনুমতি নেই। লগআউট করে আবার লগইন করুন।';
  @override
  String get ensureSignedIn =>
      'নিশ্চিত করুন যে আপনি লগইন করেছেন এবং ইন্টারনেট সচল আছে।';
  @override
  String get syncNow => 'এখনই সিঙ্ক করুন';
  @override
  String get phoneStorageBackup => 'ফোন স্টোরেজ ব্যাকআপ';
  @override
  String get offlineBackupImport => 'অফলাইন ব্যাকআপ ও ইম্পোর্ট';
  @override
  String get offlineBackupDesc =>
      'আপনার ফোনে ব্যাকআপ ফাইল এক্সপোর্ট করুন বা বিদ্যমান .db ফাইল থেকে ইম্পোর্ট করুন।';
  @override
  String get exportNow => 'এখনই এক্সপোর্ট করুন';
  @override
  String get importDb => 'ইম্পোর্ট ডিবি';
  @override
  String get exportedSuccess => 'ডাটাবেসটি ফোনের মেমোরিতে এক্সপোর্ট করা হয়েছে';
  @override
  String exportedToPath(String path) => 'ডাটাবেস এক্সপোর্ট হয়েছে: $path';
  @override
  String get exportSelectFolder => 'এক্সপোর্ট ফোল্ডার নির্বাচন করুন';
  @override
  String get exportFolderPickCanceled =>
      'এক্সপোর্ট বাতিল হয়েছে: কোনো ফোল্ডার নির্বাচন করা হয়নি।';
  @override
  String get exportFolderPickFailed =>
      'ফোল্ডার পিকার খোলা যায়নি। আবার চেষ্টা করুন।';
  @override
  String get importDatabase => 'ডাটাবেস ইম্পোর্ট করবেন?';
  @override
  String get importDatabaseWarning =>
      'এটি আপনার বর্তমান সব তথ্য মুছে ফেলবে এবং ব্যাকআপ ডাটা যোগ করবে। এটি ফেরত পাওয়া সম্ভব নয়।';
  @override
  String get importReplace => 'ইম্পোর্ট এবং পরিবর্তন';
  @override
  String get importSuccess => 'ইম্পোর্ট সফল হয়েছে!';
  @override
  String get importFailed => 'ইম্পোর্ট ব্যর্থ হয়েছে';
  @override
  String get importInvalidDbFile =>
      'শুধু বৈধ .db ফাইল নির্বাচন করুন।';
  @override
  String get medicineCategories => 'ওষুধের ধরণ';
  @override
  String get medicineCategoriesDesc =>
      'ট্যাবলেট, সিরাপ ইত্যাদি ধরণগুলো পরিচালনা করুন।';
  @override
  String get addNewType => 'নতুন ধরণ যোগ করুন (যেমন: ইনহেলার)';
  @override
  String get removeCategory => 'ধরণ মুছবেন?';
  @override
  String get removeCategoryConfirm => 'আপনি কি নিশ্চিত যে আপনি এটি মুছতে চান';
  @override
  String get removeCategoryWarning =>
      'এই ধরণের বর্তমান ওষুধগুলো মুছবে না, তবে পরবর্তীতে এডিটর সময় পরিবর্তন করতে হতে পারে।';
  @override
  String get removeBtn => 'মুছুন';
  @override
  String get languageSetting => 'ভাষা';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageBangla => 'বাংলা';
  @override
  String get logout => 'লগআউট';
  @override
  String get logoutConfirm => 'আপনি কি নিশ্চিত যে আপনি লগআউট করতে চান?';
  @override
  String get notifications => 'নোটিফিকেশন';

  // ── Reports & Others ──────────────────────────────
  @override
  String get returnsTitle => 'রিটার্ন';
  @override
  String get filterReturns => 'রিটার্ন ফিল্টার';
  @override
  String get dateRange => 'তারিখের রেঞ্জ';
  @override
  String get amountRange => 'টাকার রেঞ্জ (৳)';
  @override
  String get timeRange => 'সময়ের রেঞ্জ';
  @override
  String get anyTime => 'যেকোনো সময়';
  @override
  String get clearTime => 'সময় মুছুন';
  @override
  String get returnItems => 'রিটার্ন করুন';
  @override
  String get confirmReturn => 'রিটার্ন নিশ্চিত করুন';
  @override
  String get noItemsInvoice => 'এই ইনভয়েস থেকে কোনো আইটেম পাওয়া যায়নি।';
  @override
  String get allItemsReturned => 'এই ইনভয়েসের সব আইটেম আগে ফেরত দেওয়া হয়েছে।';
  @override
  String get someProductsSkipped => 'কিছু পণ্য বাদ দেওয়া হয়েছে';
  @override
  String get couldNotFindProducts => 'ওষুধ খুঁজে পাওয়া যায়নি';
  @override
  String get returnItemsFor => 'আইটেম রিটার্ন করুন এর জন্য:';
  @override
  String get strips => 'পাতা';
  @override
  String get pcs => 'পিস';
  @override
  String get maxReturnable => 'সর্বোচ্চ ফেরতযোগ্য';
  @override
  String get selected => 'নির্বাচিত';
  @override
  String get changeBtn => 'পরিবর্তন';
  @override
  String get salesReport => 'বিক্রয় রিপোর্ট';
  @override
  String get totalRevenue => 'মোট আয়';
  @override
  String get totalTransactions => 'মোট লেনদেন';
  @override
  String get topProduct => 'শীর্ষ পণ্য';
  @override
  String get noSalesData => 'এই সময়ের জন্য কোনো বিক্রির তথ্য নেই';
  @override
  String get exportPdf => 'পিডিএফ এক্সপোর্ট';
  @override
  String get exportCsv => 'সিএসভি এক্সপোর্ট';
  @override
  String get exportSuccess => 'রিপোর্ট সফলভাবে এক্সপোর্ট করা হয়েছে';
  @override
  String get exportFailed => 'রিপোর্ট এক্সপোর্ট করতে সমস্যা হয়েছে';
  @override
  String get today => 'আজকের';
  @override
  String get thisWeek => 'এই সপ্তাহের';
  @override
  String get thisMonth => 'এই মাসের';
  @override
  String get last3Months => 'গত ৩ মাস';
  @override
  String exportError(String error) => 'রিপোর্ট এক্সপোর্টে সমস্যা: $error';
  @override
  String get reportSaved => 'রিপোর্ট সফলভাবে সংরক্ষিত হয়েছে!';
  @override
  String get reportFailed => 'রিপোর্ট সংরক্ষণ করা যায়নি।';
  @override
  String get transactionHistory => 'লেনদেনের ইতিহাস';
  @override
  String recordsCount(int count) => '$countটি রেকর্ড';
  @override
  String get orders => 'অর্ডার';
  @override
  String get itemsSold => 'বিক্রিত ওষুধ';
  @override
  String get noTransactionsFound => 'কোনো লেনদেন পাওয়া যায়নি';
  @override
  String get tryAnotherFilter => 'অন্য কোনো তারিখ বা ফিল্টার চেষ্টা করুন';
  @override
  String get revenueTrend => 'রাজস্ব প্রবণতা';
  @override
  String get period => 'সময়কাল';
  @override
  String get customRange => 'কাস্টম রেঞ্জ';
  @override
  String get custom => 'কাস্টম';
  @override
  String get last30Days => 'গত ৩০ দিন';
  @override
  String get weekly => 'সাপ্তাহিক';
  @override
  String get monthly => 'মাসিক';
  @override
  String get yearly => 'বার্ষিক';
  @override
  String get newestFirst => 'নতুন আগে';
  @override
  String get oldestFirst => 'পুরানো আগে';
  @override
  String get amountHigh => 'টাকা (বেশি)';
  @override
  String get amountLow => 'টাকা (কম)';
  @override
  String get productAZ => 'ওষুধ A-Z';
  @override
  String get mon => 'সোম';
  @override
  String get tue => 'মঙ্গল';
  @override
  String get wed => 'বুধ';
  @override
  String get thu => 'বৃহস্পতি';
  @override
  String get fri => 'শুক্র';
  @override
  String get sat => 'শনি';
  @override
  String get sun => 'রবি';
  @override
  String get jan => 'জানু';
  @override
  String get feb => 'ফেব্রু';
  @override
  String get mar => 'মার্চ';
  @override
  String get apr => 'এপ্রিল';
  @override
  String get may => 'মে';
  @override
  String get jun => 'জুন';
  @override
  String get jul => 'জুলাই';
  @override
  String get aug => 'আগস্ট';
  @override
  String get sep => 'সেপ্টেম্বর';
  @override
  String get oct => 'অক্টোবর';
  @override
  String get nov => 'নভেম্বর';
  @override
  String get dec => 'ডিসেম্বর';
  @override
  String get others => 'অন্যান্য';
  @override
  String get expiringSoonTitle => 'দ্রুত মেয়াদোত্তীর্ণ হবে';
  @override
  String get lowStockTitle => 'কম স্টকের ওষুধ';
  @override
  String get exportOrderList => 'অর্ডার লিস্ট এক্সপোর্ট';
  @override
  String get noExpiringSoon => 'নিকট ভবিষ্যতে মিয়াদ শেষ হবে এমন কোনো ওষুধ নেই';
  @override
  String get noLowStock => 'স্টক কম এমন কোনো ওষুধ নেই';
  @override
  String get remainingPcs => 'পিস অবশিষ্ট';
  @override
  String get boxesSuffix => 'বক্স';
  @override
  String get stripsSuffix => 'পাতা';
  @override
  String get notificationsTitle => 'নোটিফিকেশন';
  @override
  String get noNotifications => 'কোনো নোটিফিকেশন নেই';
  @override
  String get markAllRead => 'সব পড়া হয়েছে হিসেবে চিহ্নিত করুন';
  @override
  String get profileTitle => 'প্রোফাইল';
  @override
  String get signOut => 'লগআউট';
  @override
  String get signOutConfirm => 'আপনি কি নিশ্চিত যে আপনি লগআউট করতে চান?';
  @override
  String get accountInfo => 'অ্যাকাউন্ট তথ্য';
  @override
  String get changePassword => 'পাসওয়ার্ড পরিবর্তন';
  @override
  String get currentPassword => 'বর্তমান পাসওয়ার্ড';
  @override
  String get newPassword => 'নতুন পাসওয়ার্ড';
  @override
  String get updatePassword => 'পাসওয়ার্ড আপডেট করুন';
  @override
  String get passwordUpdated => 'পাসওয়ার্ড সফলভাবে আপডেট করা হয়েছে';

  // ── Profile Screen Extension ───────────────────
  @override
  String get emailAddress => 'ইমেল ঠিকানা';
  @override
  String get subscriptionValidUntil => 'সাবস্ক্রিপশনের মেয়াদ';
  @override
  String get subscriptionManagement => 'সাবস্ক্রিপশন ম্যানেজমেন্ট';
  @override
  String get activeSubscription => 'সক্রিয় সাবস্ক্রিপশন';
  @override
  String get expiredInactive => 'মেয়াদোত্তীর্ণ / নিষ্ক্রিয়';
  @override
  String get activateBtn => 'সক্রিয় করুন';
  @override
  String get renewalDate => 'রিনিউয়াল তারিখ';
  @override
  String get editDisplayName => 'নাম পরিবর্তন করুন';
  @override
  String get editPhoneNumber => 'ফোন নম্বর পরিবর্তন করুন';
  @override
  String get updateAdminPin => 'অ্যাডমিন পিন আপডেট করুন';
  @override
  String get setLocalPassword => 'লোকাল পাসওয়ার্ড সেট করুন';
  @override
  String get setLocalPasswordSubtitle =>
      'ইমেল দিয়ে লগইন করার জন্য একটি পাসওয়ার্ড তৈরি করুন';
  @override
  String get googleManagedAccount => 'গুগল ম্যানেজড অ্যাকাউন্ট';
  @override
  String get googleManagedSubtitle => 'আপনি আপনার গুগল আইডি দিয়ে লগইন করেছেন';
  @override
  String get newDisplayName => 'নতুন নাম';
  @override
  String get nameRequired => 'নাম প্রয়োজন';
  @override
  String get max100Chars => 'সর্বোচ্চ ১০০ অক্ষর';
  @override
  String get currentPin => 'বর্তমান পিন';
  @override
  String get newPin => 'নতুন পিন';
  @override
  String get confirmPin => 'পিন নিশ্চিত করুন';
  @override
  String get pinUpdated => 'পিন সফলভাবে আপডেট করা হয়েছে!';
  @override
  String get incorrectPin => 'ভুল বর্তমান পিন।';
  @override
  String get nameUpdated => 'নাম সফলভাবে আপডেট করা হয়েছে!';
  @override
  String get phoneUpdated => 'ফোন নম্বর সফলভাবে আপডেট করা হয়েছে!';
  @override
  String get saveNameBtn => 'নাম সংরক্ষণ করুন';
  @override
  String get savePhoneBtn => 'ফোন নম্বর সংরক্ষণ করুন';
  @override
  String get phoneNumberLabel => 'ফোন নম্বর';
  @override
  String get newPhoneNumber => 'নতুন ফোন নম্বর';
  @override
  String get phoneRequired => 'ফোন নম্বর প্রয়োজন';
  @override
  String get phoneMustBe11Digits => 'ফোন নম্বর অবশ্যই ১১ সংখ্যার হতে হবে';
  @override
  String get phoneDigitsOnly => 'ফোন নম্বরে কেবল সংখ্যা থাকতে হবে';
  @override
  String get updateSecurityPin => 'সিকিউরিটি পিন আপডেট করুন';
  @override
  String get secureLocalAccount => 'লোকাল অ্যাকাউন্ট সুরক্ষিত করুন';
  @override
  String get pinsDoNotMatch => 'পিন দুটি মিলছে না';
  @override
  String get minFourDigits => 'কমপক্ষে ৪ ডিজিট';
  @override
  String get adminAccessSecurity => 'অ্যাডমিন প্রবেশ';
  @override
  String get biometricUnlockAdmin => 'বায়োমেট্রিক দিয়ে অ্যাডমিন খুলুন';
  @override
  String get biometricUnlockAdminHelper =>
      'অ্যাডমিন পোর্টাল দ্রুত খুলতে আঙুলের ছাপ, ফেস আইডি বা ডিভাইসের বায়োমেট্রিক ব্যবহার করুন। ব্যাকআপ হিসেবে পিন থাকবে।';
  @override
  String get biometricNotAvailable =>
      'এই ডিভাইসে বায়োমেট্রিক বর্তমানে ব্যবহারযোগ্য নয়।';
  @override
  String get biometricSetupRequired =>
      'ফোনের সেটিংসে ফিঙ্গারপ্রিন্ট বা ফেস আনলক সেটআপ করে আবার চেষ্টা করুন।';
  @override
  String get biometricLockedOut =>
      'বায়োমেট্রিক লক হয়ে গেছে। একবার ডিভাইস আনলক করে আবার চেষ্টা করুন।';
  @override
  String get biometricTryAgainLater =>
      'অনেকবার চেষ্টা হয়েছে। একটু পরে আবার বায়োমেট্রিক চেষ্টা করুন।';
  @override
  String get biometricCanceled => 'বায়োমেট্রিক যাচাইকরণ বাতিল হয়েছে।';
  @override
  String get biometricPromptEnable =>
      'বায়োমেট্রিক অ্যাডমিন আনলক চালু করতে আঙুলের ছাপ বা মুখ দিয়ে নিশ্চিত করুন।';
  @override
  String get biometricPromptDisable =>
      'বায়োমেট্রিক অ্যাডমিন আনলক বন্ধ করতে আঙুলের ছাপ বা মুখ দিয়ে নিশ্চিত করুন।';
  @override
  String get biometricAuthFailed => 'বায়োমেট্রিক যাচাইকরণ সফল হয়নি।';
  @override
  String get adminLoginTitle => 'অ্যাডমিন লগইন';
  @override
  String get adminLoginEnterPin => 'চালিয়ে যেতে অ্যাডমিন পিন লিখুন';
  @override
  String get adminLoginWrongPin => 'ভুল পিন। আবার চেষ্টা করুন।';
  @override
  String get adminLoginPinEmpty => 'পিন লিখুন';
  @override
  String get adminLoginBtn => 'লগইন';
  @override
  String get otpSent => 'ওটিপি আপনার নিবন্ধিত নম্বরে পাঠানো হয়েছে';
  @override
  String get otpRequired => 'পিন রিসেট করতে ওটিপি প্রয়োজন';
  @override
  String get forgotPinTitle => 'অ্যাডমিন পিন ভুলে গেছেন?';
  @override
  String resetPinSubtitle(String contact) =>
      'আমরা $contact নম্বরে একটি রিসেট কোড পাঠাব';
  @override
  String get resetPinWithPasswordSubtitle =>
      'আপনার অ্যাকাউন্ট পাসওয়ার্ড দিয়ে নতুন অ্যাডমিন পিন সেট করুন।';
  @override
  String get forgotPin => 'পিন ভুলে গেছেন?';
  @override
  String get pinResetMethodTitle => 'রিসেট পদ্ধতি নির্বাচন করুন';
  @override
  String get resetWithOtp => 'ওটিপি দিয়ে রিসেট';
  @override
  String get resetWithPassword => 'অ্যাকাউন্ট পাসওয়ার্ড ব্যবহার করুন';
  @override
  String get enterOtpCode => 'ওটিপি কোড দিন';
  @override
  String get resendOtp => 'ওটিপি পুনরায় পাঠান';
  @override
  String get sendOtp => 'ওটিপি পাঠান';
  @override
  String get resetPin => 'পিন রিসেট করুন';
  @override
  String get passwordRequiredForPinReset =>
      'পিন রিসেট করতে অ্যাকাউন্ট পাসওয়ার্ড দিন';
  @override
  String get adminPinSetupTitle => 'অ্যাডমিন পিন সেট করুন';
  @override
  String get adminPinSetupSubtitle =>
      'প্রথমবার ব্যবহারের জন্য অ্যাডমিন পিন তৈরি করুন';
  @override
  String get adminPinSetupBtn => 'পিন সেট করুন';
  @override
  String get adminPinSetupFailed => 'অ্যাডমিন পিন সেট করা যায়নি।';
  @override
  String get biometricUnlockReason => 'অ্যাডমিন পোর্টাল আনলক করুন';
  @override
  String get biometricUseFace => 'ফেস আইডি ব্যবহার করুন';
  @override
  String get biometricUseFingerprint => 'আঙুলের ছাপ ব্যবহার করুন';
  @override
  String get biometricUseGeneric => 'বায়োমেট্রিক ব্যবহার করুন';
  @override
  String get multiDeviceSellingTitle => 'বিক্রয় ডিভাইস';
  @override
  String get multiDeviceSellingSubtitle =>
      'একটি ফোনে মাত্র চেকআউট চালু থাকে। সক্রিয় ডিভাইস অন্য ফোনে বিক্রয় হস্তান্তর করতে পারে।';
  @override
  String get activeSellerBadge => 'সক্রিয়';
  @override
  String get thisDeviceLabel => 'এই ফোন';
  @override
  String get useAsActiveSeller => 'বিক্রয়ের জন্য ব্যবহার করুন';
  @override
  String get transferSellingConfirmTitle => 'বিক্রয় স্থানান্তর?';
  @override
  String get transferSellingConfirmBody =>
      'আবার সক্রিয় না করা পর্যন্ত এই ফোনে চেকআউট বন্ধ থাকবে।';
  @override
  String get onlyActiveDeviceCanSwitch =>
      'শুধুমাত্র বর্তমানে সক্রিয় বিক্রয় ফোন অন্য ডিভাইস বেছে নিতে পারে।';
  @override
  String get checkoutRequiresActiveDevice =>
      'চেকআউট শুধু সক্রিয় বিক্রয় ফোনে। সেটিংসে পরিবর্তন করুন।';
  @override
  String get refreshDeviceList => 'রিফ্রেশ';
  @override
  String get sellingDeviceListError =>
      'ডিভাইস লোড করা যায়নি। রিফ্রেশ চেষ্টা করুন।';
  @override
  String get passwordSet => 'পাসওয়ার্ড সফলভাবে তৈরি হয়েছে!';
  @override
  String get adminRole => 'প্রশাসক';
  @override
  String get renew => 'রিনিউ করুন';
  @override
  String get activate => 'সক্রিয় করুন';
  @override
  String get required => 'আবশ্যক';
  @override
  String get min8Chars => 'ন্যূনতম ৮টি অক্ষর';
  @override
  String get confirmPassword => 'পাসওয়ার্ড নিশ্চিত করুন';
  @override
  String get passwordsDoNotMatch => 'পাসওয়ার্ড মিলছে না';
  @override
  String get profilePhotoUpdated => 'প্রোফাইল ছবি আপডেট হয়েছে';
  @override
  String get profilePhotoPickFailed => 'গ্যালারি থেকে ছবি নির্বাচন করা যায়নি';

  // ── Product Edit Extension ─────────────────────
  @override
  String get genericDescription => 'জেনেরিক / বিবরণ';
  @override
  String get companyNameOptional => 'কোম্পানির নাম (ঐচ্ছিক)';
  @override
  String get supplierNameOptional => 'সরবরাহকারীর নাম (ঐচ্ছিক)';
  @override
  String get supplierPhoneOptional => 'সরবরাহকারীর ফোন (ঐচ্ছিক)';
  @override
  String get barcodeOptional => 'বারকোড (ঐচ্ছিক)';
  @override
  String get expiryDateOptional => 'মিয়াদের তারিখ (ঐচ্ছিক)';
  @override
  String get pricePerStripLabel => 'দাম / পাতা';
  @override
  String get pricePerPcLabel => 'দাম / পিস';
  @override
  String get lowStockWarningBox => 'কম স্টক সতর্কতা (বক্স)';
  @override
  String get activeBatches => 'সক্রিয় ব্যাচসমূহ';
  @override
  String get noActiveBatches => 'কোনো সক্রিয় ব্যাচ নেই। স্টক ০।';
  @override
  String pcsSuffixCount(int n) => '$n পিস';
  @override
  String get saveChanges => 'পরিবর্তন সংরক্ষণ করুন';
  @override
  String get medicineType => 'ওষুধের ধরণ';
  @override
  String editProductTitle(String name) => 'সম্পাদনা: $name';
  @override
  String get productDetailsTitle => 'ওষুধের বিবরণ';
  @override
  String batchRemaining(int str, int pcs) => '($str পাতা + $pcs)';

  // ── Bulk Import Screen ──────────────────────────
  @override
  String get noFileSelected => 'কোনো ফাইল নির্বাচন করা হয়নি';
  @override
  String selectedFile(String name) => 'ফাইল: $name';
  @override
  String get selectCsvExcel => 'CSV/Excel ফাইল নির্বাচন করুন';
  @override
  String get showFileStructure => 'ফাইলের গঠন উদাহরণ দেখুন';
  @override
  String get uploadCsvHint =>
      'ইম্পোর্ট করার আগে আপনার ওষুধগুলো দেখতে একটি CSV বা Excel ফাইল আপলোড করুন।';
  @override
  String get xlsNotSupported =>
      'পুরানো .xls ফাইল সমর্থিত নয়। অনুগ্রহ করে .xlsx বা .csv ব্যবহার করুন';
  @override
  String unsupportedFileType(String ext) => 'অসমর্থিত ফাইলের ধরণ: $ext';
  @override
  String readyToImport(int n) => 'ইম্পোর্টের জন্য প্রস্তুত ($n)';
  @override
  String errorsCount(int n) => 'ত্রুটি ($n)';
  @override
  String get confirmImport => 'ইম্পোর্ট নিশ্চিত করুন';
  @override
  String confirmImportMsg(int n) =>
      'আপনি কি নিশ্চিত যে আপনি আপনার ইনভেন্টরিতে $nটি আইটেম ইম্পোর্ট করতে চান?';
  @override
  String get yesImport => 'হ্যাঁ, ইম্পোর্ট করুন';
  @override
  String importNItems(int n) => '$nটি আইটেম ইম্পোর্ট করুন';
  @override
  String get noValidProducts => 'কোনো বৈধ ওষুধ পাওয়া যায়নি।';
  @override
  String get noErrorsFound => 'কোনো ত্রুটি পাওয়া যায়নি! আপনি এগুতে পারেন।';
  @override
  String get boxPrice => 'বক্সের দাম';
  @override
  String get stockPcsLabel => 'স্টক পিস';
  @override
  String get xlsLegacyNotSupported =>
      'পুরানো .xls ফাইল সমর্থিত নয়। অনুগ্রহ করে .xlsx বা CSV হিসেবে সেভ করুন।';
  @override
  String get failedToReadFile => 'ফাইল পড়তে ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override
  String get fileIsEmpty => 'নির্বাচিত ফাইলটি খালি।';
  @override
  String missingRequiredColumn(String col) => 'প্রয়োজনীয় কলাম নেই: $col';
  @override
  String rowSkippedNameEmpty(int row) =>
      'সারি $row: ওষুধের নাম খালি রাখা যাবে না। সারিটি বাদ দেওয়া হয়েছে।';
  @override
  String invalidExpiryUsingDefault(int row, String val) =>
      'সারি $row: অকার্যকর মেয়াদ উত্তীর্ণের তারিখ \'$val\'; ১ বছরের ডিফল্ট তারিখ ব্যবহার করা হচ্ছে।';
  @override
  String rowSkippedDataError(int row, String err) =>
      'সারি $row: ডেটা ফরম্যাটে ভুল। সারিটি বাদ দেওয়া হয়েছে। ($err)';
  @override
  String get noValidRowsFound =>
      'কোনো বৈধ সারি পাওয়া যায়নি। অনুগ্রহ করে ভুলের তালিকা দেখুন।';
  @override
  String bulkImportSuccess(int n) =>
      '$n টি ওষুধ ডেটাবেসে সফলভাবে যুক্ত করা হয়েছে!';
  @override
  String databaseInsertFailed(String err) =>
      'ডেটাবেসে যুক্ত করতে ব্যর্থ হয়েছে: $err';
  @override
  String get failedToImportReviewErrors =>
      'ওষুধগুলো ডেটাবেসে যুক্ত করতে ব্যর্থ হয়েছে। ভুলের তালিকা দেখুন।';
  @override
  String get bulkImportPreview => 'বাল্ক ইম্পোর্ট প্রিভিউ';
  @override
  String get editThisRow => 'এই সারিটি সম্পাদনা করুন';
  @override
  String get deleteThisRow => 'ইম্পোর্ট থেকে এই সারিটি মুছে ফেলুন';
  @override
  String get subscriptionTitle => 'সাবস্ক্রিপশন';
  @override
  String subscriptionRenewalDaysLeft(int daysRemaining) {
    if (daysRemaining < 0) return 'মেয়াদ শেষ';
    if (daysRemaining == 0) return 'আজ মেয়াদ শেষ';
    if (daysRemaining == 1) return '১ দিন বাকি';
    return '$daysRemaining দিন বাকি';
  }

  @override
  String get subscriptionRenewalUnavailable => 'রিনিউয়াল তারিখ নেই';
  @override
  String get subscribeBtn => 'এখনই সাবস্ক্রাইব করুন';
  @override
  String get currentPlan => 'বর্তমান প্ল্যান';
  @override
  String get expiresOn => 'মিয়াদ শেষ হবে';
  @override
  String get trialExpired => 'ট্রায়াল শেষ';
  @override
  String get renewBtn => 'রিনিউ করুন';
  @override
  String get ocrScanResult => 'ওসিআর ফলাফল';
  @override
  String get addAllToCart => 'সব কার্টে যোগ করুন';
  @override
  String get confirmedItems => 'নিশ্চিত আইটেমসমূহ';
  @override
  String get generalInfo => 'সাধারণ তথ্য';
  @override
  String get packaging => 'প্যাকেজিং';
  @override
  String get pricing => 'মূল্য নির্ধারণ';
  @override
  String get inventory => 'ইনভেন্টরি';
  @override
  String get expiryBatch => 'মেয়াদ / ব্যাচ';
  @override
  String get supplierInfo => 'সরবরাহকারীর তথ্য';
  @override
  String get selectExpiryDate => 'অনুগ্রহ করে মেয়াদের তারিখ নির্বাচন করুন।';
  @override
  String get batchNumber => 'ব্যাচ নম্বর';
  @override
  String get barcodeLabel => 'বারকোড (ঐচ্ছিক)';
  @override
  String get scanBtn => 'স্ক্যান';
  @override
  String get stripsPerBox => 'বক্স প্রতি পাতা';
  @override
  String get failedToSaveProduct =>
      'পণ্য সংরক্ষণ করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।';
  @override
  String get noDate => 'কোনো তারিখ নেই';
  @override
  String get bulkImport => 'বাল্ক ইম্পোর্ট';
  @override
  String get wizardBack => 'পিছনে';
  @override
  String get wizardContinue => 'এগিয়ে যান';
  @override
  String get changeMedType => 'ওষুধের ধরন পরিবর্তন করুন';
  @override
  String get returns => 'ফেরত সমূহ';
  @override
  String get searchBtn => 'অনুসন্ধান';
  @override
  String get searchHelpText => 'ইনভয়েস নম্বর বা ওষুধের নাম দিয়ে খুঁজুন';
  @override
  String get noResults => 'কোনো ফলাফল পাওয়া যায়নি';
  @override
  String get fullyReturned => 'সম্পূর্ণ ফেরত দেওয়া হয়েছে';
  @override
  String get qtyLabel => 'পরিমাণ';
  @override
  String get retLabel => 'ফেরত';
  @override
  String get batchLabel => 'ব্যাচ';
  @override
  String get returnsProcessed => 'ফেরত সফলভাবে সম্পন্ন হয়েছে!';
  @override
  String get sortBy => 'সর্ট করুন';
  @override
  String get sortAmountHigh => 'মূল্য: বেশি থেকে কম';
  @override
  String get sortAmountLow => 'মূল্য: কম থেকে বেশি';
  @override
  String get filters => 'ফিল্টারসমূহ';

  // ── Common / Shared ───────────────────────────────
  @override
  String get loading => 'লোড হচ্ছে...';
  @override
  String get error => 'সমস্যা';
  @override
  String get success => 'সফল';
  @override
  String get tryAgain => 'আবার চেষ্টা করুন';
  @override
  String get toLabel => 'থেকে';
  @override
  String get close => 'বন্ধ করুন';
  @override
  String get open => 'খুলুন';
  @override
  String get confirm => 'নিশ্চিত';
  @override
  String get apply => 'প্রয়োগ';
  @override
  String get search => 'খুঁজুন';
  @override
  String get filter => 'ফিল্টার';
  @override
  String get sort => 'সাজান';
  @override
  String get noResultsFound => 'কোনো ফলাফল পাওয়া যায়নি';
  @override
  String get boxes => 'বক্স';
  @override
  String get minAmount => 'সর্বনিম্ন ৳';
  @override
  String get maxAmount => 'সর্বোচ্চ ৳';

  @override
  String get deselectAll => 'সব বাতিল করুন';
  @override
  String get selectAll => 'সব নির্বাচন করুন';
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

  @override
  String get productListEmpty => 'আপনার ওষুধের তালিকা বর্তমানে খালি।';
  @override
  String get noProductsMatchCriteria =>
      'আপনার সার্চ বা ফিল্টার অনুযায়ী কোনো ওষুধ পাওয়া যায়নি।';
  @override
  String get clearAllFilters => 'সব ফিল্টার মুছুন';
  @override
  String get inStock => 'স্টকে আছে';
  @override
  String get pieces => 'পিস';
  @override
  String get stripPrice => 'পাতা ৳';
  @override
  String get edit => 'সম্পাদনা';
  @override
  String get cancel => 'বাতিল';
  @override
  String get delete => 'মুছুন';
  @override
  String get saveBtn => 'সংরক্ষণ';
  @override
  String unitPrice(String unit) => '$unit এর দাম';
  @override
  String addedToCartDetail(String name, int qty, String unit) =>
      '$name ($qty $unit) কার্টে যোগ করা হয়েছে';
  @override
  String get noCloseMatchFound =>
      'কোনো কাছাকাছি মিল পাওয়া যায়নি। দয়া করে নাম পরিবর্তন করুন।';
  @override
  String deleteProductsConfirmation(int count) =>
      'আপনি কি নিশ্চিত যে আপনি $count টি পণ্য মুছে ফেলতে চান?';

  @override
  String get deleteSelectedTooltip => 'নির্বাচিতগুলো মুছুন';
  @override
  String get taka => 'টাকা';
  @override
  String get companyName => 'কোম্পানি নাম';
  @override
  String get scan => 'স্ক্যান';
  @override
  String get exp => 'মেয়াদ';
  @override
  String get syrupHint => 'যেমন: ১০০ মিলি প্রতি বোতল';
  @override
  String get tube => 'টিউব';
  @override
  String get vial => 'ভায়াল';
  @override
  String get bottle => 'বোতল';
  @override
  String get sachet => 'স্যাসেট';
  @override
  String get inhaler => 'ইনহেলার';
  @override
  String get patch => 'প্যাচ';
  @override
  String get unit => 'ইউনিট';
  @override
  String get ml => 'মিলি';
  @override
  String get grams => 'গ্রাম';
  @override
  String get price => 'মূল্য';
  @override
  String get invoicePrefix => 'ইনভয়েস:';
  @override
  String get onePcSuffix => ' (১ পিস)';
  @override
  String voiceError(String error) => 'ভয়েস সমস্যা: $error';
  @override
  String ocrError(String error) => 'ওসিআর সমস্যা: $error';
  @override
  String get googleIdTokenError => 'গুগল আইডি টোকেন পাওয়া যায়নি।';
  @override
  String get createAccount => 'অ্যাকাউন্ট তৈরি করুন';
  @override
  String get unknownInvoice => 'অজানা ইনভয়েস';

  // --- Parameterized ---
  @override
  String productStockDetails(int boxes, int strips, int pcs, int min) =>
      '$boxes বক্স • $strips পাতা • $pcs পিস অবশিষ্ট (সর্বনিম্ন: $min)';

  @override
  String expiresDate(DateTime date) =>
      'মিয়াদ শেষ: ${date.day}/${date.month}/${date.year}';

  @override
  String productQuantity(String name, int quantity) => '$name × $quantity';

  @override
  String get fileStructureExample => 'ফাইলের গঠন উদাহরণ (CSV / Excel)';
  @override
  String get expiryFormatHint =>
      'মেয়াদ উত্তীর্ণের ফরম্যাট: YYYY-MM-DD। ব্যাচ নম্বর (BatchNo) ঐচ্ছিক।';
  @override
  String get csvTemplateSuccess => 'CSV টেমপ্লেট সফলভাবে ডাউনলোড হয়েছে।';
  @override
  String get csvTemplateFail => 'CSV টেমপ্লেট ডাউনলোড করতে ব্যর্থ হয়েছে।';
  @override
  String get excelTemplateSuccess => 'Excel টেমপ্লেট সফলভাবে ডাউনলোড হয়েছে।';
  @override
  String get excelTemplateFail => 'Excel টেমপ্লেট ডাউনলোড করতে ব্যর্থ হয়েছে।';
  @override
  String get downloadCsvTemplate => 'CSV টেমপ্লেট ডাউনলোড করুন';
  @override
  String get downloadExcel => 'Excel ডাউনলোড করুন';
  @override
  String get rawCsvExample => 'র CSV উদাহরণ (সম্পূর্ণ গঠন):';
  @override
  String get editImportedProduct => 'আমদানি করা পণ্য সম্পাদনা করুন';
  @override
  String get pricingPackaging => 'মূল্য ও প্যাকেজিং';
  @override
  String get inventoryTracking => 'ইনভেন্টরি ও ট্র্যাকিং';
  @override
  String get saveChangesLabel => 'পরিবর্তন সংরক্ষণ করুন';
  @override
  String get selectExpiryDateError =>
      'অনুগ্রহ করে একটি মেয়াদ উত্তীর্ণের তারিখ নির্বাচন করুন।';
  @override
  String get requiredLabel => 'প্রয়োজন';
  @override
  String get mustBeGreaterThanZero => '০ এর বেশি হতে হবে';
  @override
  String get minStockWarningBox => 'কম স্টকের সতর্কতা (বক্স)';
  @override
  String get productNameLabel => 'পণ্যের নাম';
  @override
  String get barcodeLabelOptional => 'বারকোড (ঐচ্ছিক)';
  @override
  String get stripsPerBoxLabel => 'বক্স প্রতি পাতা';
  @override
  String get pcsPerStripLabel => 'পাতা প্রতি পিস';
  @override
  String get pricePerBoxLabel => 'প্রতি বক্সের দাম';
  @override
  String get stockInBoxesLabel => 'স্টক (বক্স)';
  @override
  String get selectExpiry => 'মেয়াদ চয়ন করুন';
  @override
  String get medTypeLabel => 'ওষুধের ধরন';
  @override
  String get supplierNameLabel => 'সরবরাহকারীর নাম';
  @override
  String get supplierPhoneLabel => 'সরবরাহকারীর ফোন';

  // ── Expiring Soon & Low Stock ──────────────────────
  @override
  String allProductsValidForDays(int days) =>
      'সব পণ্যের মেয়াদ $days দিনের বেশি বাকি।';
  @override
  String get filterAll => 'সব';
  @override
  String get filterCritical => 'সংকটজনক';
  @override
  String get filterWarning => 'সতর্কতা';
  @override
  String get filterNotice => 'বিজ্ঞপ্তি';
  @override
  String get allCompanies => 'সব কোম্পানি';
  @override
  String nCompanies(int n) => '$n টি কোম্পানি';
  @override
  String productsCount(int n) => '$n টি পণ্য';
  @override
  String get sortSoonestFirst => 'নিকটতম মেয়াদ আগে';
  @override
  String get sortLatestFirst => 'দূরতম মেয়াদ আগে';
  @override
  String get sortNameZA => 'Z → A';
  @override
  String get setOrderQuantities => 'অর্ডারের পরিমাণ নির্ধারণ করুন';
  @override
  String get enterBoxesToOrder =>
      'প্রতিটি পণ্যের জন্য কতটি বক্স অর্ডার করবেন লিখুন।';
  @override
  String get next => 'পরবর্তী';
  @override
  String get filterOutOfStock => 'স্টক শেষ';
  @override
  String get sortMostUrgent => 'সবচেয়ে জরুরি';
  @override
  String get sortBiggestDeficit => 'সবচেয়ে বেশি ঘাটতি';
  @override
  String get confirmOrderQuantities => 'অর্ডারের পরিমাণ নিশ্চিত করুন';
  @override
  String deficitUnits(int n, String unit) => 'ঘাটতি: $n $unit';

  @override
  String get callSupplier => 'সরবরাহকারীকে কল করুন';
  @override
  String get noSupplierContactFound => 'কোনো যোগাযোগের নম্বর নেই';

  @override
  String remainingUnits(int n, String unit) => '$n $unit বাকি আছে';

  @override
  String extraUnits(int n, String unit) => '$n $unit অতিরিক্ত';

  @override
  String stockLevelPercent(int n) => '$n% লেভেল';

  // ── Manual Add ────────────────────────────────────
  @override
  String get manualAddTitle => 'ম্যানুয়াল যোগ';
  @override
  String get doneBtn => 'সম্পন্ন';
  @override
  String setQuantityFor(String type, String name) =>
      '$type পরিমাণ নির্ধারণ করুন:\n$name';
  @override
  String get enterAmount => 'পরিমাণ লিখুন...';

  // ── OCR Scan Result ────────────────────────────────
  @override
  String get reviewScanResults => 'স্ক্যান ফলাফল পর্যালোচনা করুন';
  @override
  String get scannedImage => 'স্ক্যান করা ছবি';
  @override
  String get noMedicineDetectedTryAgain =>
      'কোনো ওষুধের নাম পাওয়া যায়নি। আবার চেষ্টা করুন।';
  @override
  String get selectedForImport => 'আমদানির জন্য নির্বাচিত:';

  // ── Subscription ──────────────────────────────────
  @override
  String get elevatePharmacy => 'আপনার ফার্মেসি উন্নত করুন';
  @override
  String get choosePlanDesc =>
      'আপনার ব্যবসার প্রয়োজনীয়তা অনুযায়ী প্ল্যান বেছে নিন। যেকোনো সময় পরিবর্তন বা বাতিল করুন।';
  @override
  String get monthlyBilling => 'মাসিক';
  @override
  String get yearlySave20 => 'বার্ষিক (২০% সাশ্রয়)';
  @override
  String get haveCouponCode => 'কুপন কোড আছে?';
  @override
  String get enterCodeHere => 'এখানে কোড লিখুন...';
  @override
  String get couponApplied => 'কুপন সফলভাবে প্রয়োগ করা হয়েছে!';
  @override
  String get invalidCoupon => 'অকার্যকর কুপন কোড।';
  @override
  String get couponExpired => 'কুপনের মেয়াদ শেষ হয়ে গেছে।';
  @override
  String get couponLimitReached => 'কুপন ব্যবহারের সীমা অতিক্রম করেছে।';
  @override
  String discountAmount(String amount) => 'ছাড়: ৳$amount';
  @override
  String freeDaysAdded(int days) => '$days দিন ফ্রি যোগ করা হবে';
  @override
  String get getStartedSubscription => 'সাবস্ক্রিপশন শুরু করুন';
  @override
  String get epsSafePayment => 'EPS নিরাপদ পেমেন্ট';
  @override
  String itemsDetected(int n) => '$n টি আইটেম শনাক্ত হয়েছে';
  @override
  String get retake => 'আবার তুলুন';
  @override
  String get scannedText => 'স্ক্যান করা টেক্সট';
  @override
  String matchPercent(int n) => '$n% মিল';
  @override
  String get exactMatchFound => 'সঠিক মিল পাওয়া গেছে';
  @override
  String get multipleMatchesSelect => 'একাধিক মিল — অনুগ্রহ করে নির্বাচন করুন:';
  @override
  String get selectCorrectProduct => '— সঠিক পণ্য নির্বাচন করুন —';
  @override
  String get statusAccepted => 'গৃহীত';
  @override
  String get statusRejected => 'প্রত্যাখ্যাত';
  @override
  String get statusPending => 'বিচারাধীন';
  @override
  String get undoReject => 'বাতিল পূর্বাবস্থায় ফেরান';
  @override
  String get reject => 'প্রত্যাখ্যান করুন';
  @override
  String get accept => 'গ্রহণ করুন';
  @override
  String get selectProductFirst =>
      'অনুগ্রহ করে প্রথমে ড্রপডাউন থেকে একটি পণ্য নির্বাচন করুন।';
  @override
  String productsAddedToCart(int n) => '$n টি পণ্য কার্টে যোগ করা হয়েছে।';
  @override
  String get noMatchesFound => 'কোনো মিল পাওয়া যায়নি';
  @override
  String get tryRetakingPhoto => 'ভালো আলোতে আবার ছবি তুলে দেখুন।';
  @override
  String get commitValidItems => 'বৈধ আইটেম নিশ্চিত করুন';
  @override
  String get resolveSelectionsFirst => 'আগে নির্বাচন নিষ্পত্তি করুন';

  // ── Missing Home / Drawer Strings ─────────────────
  @override
  String get hide => 'লুকান';
  @override
  String get manual => 'ম্যানুয়াল';
  @override
  String get ocr => 'ওসিআর (ছবি)';
  @override
  String get voice => 'ভয়েস';
  @override
  String get scannerActiveExpand => 'স্ক্যানার সক্রিয় — বড় করতে ট্যাপ করুন';
  @override
  String get scannerPausedExpand => 'স্ক্যানার থামানো — বড় করতে ট্যাপ করুন';
  @override
  String get cameraPaused => 'ক্যামেরা থামানো আছে';
  @override
  String get tapToResume => 'চালু করতে ট্যাপ করুন';
  @override
  String get tapScannerToPauseResume =>
      'থামাতে/চালু করতে স্ক্যানারে ট্যাপ করুন';
  @override
  String get scannerPausedTapToResume =>
      'স্ক্যানার থামানো — চালু করতে ট্যাপ করুন';
  @override
  String get collapse => 'ছোট করুন';
  @override
  String get cartIsEmpty => 'কার্ট খালি';
  @override
  String get scanItemToBegin => 'শুরু করতে ওষুধ স্ক্যান করুন';
  @override
  String get totalPayable => 'সর্বমোট প্রদেয়';
  @override
  String get checkout => 'চেকআউট করো';
  @override
  String get checkoutFailed => 'চেকআউট ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
  @override
  String get itemWord => 'ওষুধ';
  @override
  String get itemsWord => 'ওষুধ';
  @override
  String get navHome => 'হোম';
  @override
  String get navManagement => 'ব্যবস্থাপনা';
  @override
  String get navInventory => 'ইনভেন্টরি';
  @override
  String get driveBackupNotSynced => 'ড্রাইভ ব্যাকআপ: সিঙ্ক করা হয়নি';
  @override
  String get driveBackupSyncing => 'ড্রাইভ ব্যাকআপ: সিঙ্ক হচ্ছে...';
  @override
  String get driveBackupFailed => 'ড্রাইভ ব্যাকআপ: ব্যর্থ হয়েছে';
  @override
  String syncedAt(String time) => 'সিঙ্ক হয়েছে: ';
}
