/// Languages the prototype ships with.
enum AppLanguage {
  en('English', 'EN'),
  // A single letter for Khmer: the two-character cluster ខ្ម stacks its
  // subscript vertically and turns into a blob at badge size.
  km('ភាសាខ្មែរ', 'ខ');

  const AppLanguage(this.label, this.short);

  /// Name of the language, written in that language.
  final String label;

  /// Two-character badge used in the compact switcher.
  final String short;
}

/// Every user-facing string in the app, in English and Khmer.
///
/// Typed getters rather than a key/value map, so a missing translation is a
/// compile error instead of a blank label at runtime.
class AppText {
  const AppText(this.lang);

  final AppLanguage lang;

  String _(String en, String km) => lang == AppLanguage.km ? km : en;

  bool get isKhmer => lang == AppLanguage.km;

  // ------------------------------------------------------------ roles / demo
  String get demoRole => _('DEMO ROLE', 'តួនាទីសាកល្បង');
  String get roleCustomer => _('Customer', 'អតិថិជន');
  String get roleKitchen => _('Kitchen', 'ផ្ទះបាយ');
  String get roleCashier => _('Cashier', 'អ្នកគិតលុយ');
  String get roleAdmin => _('Admin', 'អ្នកគ្រប់គ្រង');
  String get language => _('Language', 'ភាសា');

  // ---------------------------------------------------------------- accounts
  String get signIn => _('Sign in', 'ចូលប្រើ');
  String get staffSignIn => _('Staff sign in', 'បុគ្គលិកចូលប្រើ');
  String get signOut => _('Sign out', 'ចាកចេញ');
  String get customerView => _('Customer view', 'ទិដ្ឋភាពអតិថិជន');
  String get myWorkspace => _('My workspace', 'កន្លែងធ្វើការ');
  String get chooseYourName => _('Tap your name', 'ចុចលើឈ្មោះរបស់អ្នក');
  String get enterPin => _('Enter your PIN', 'បញ្ចូលលេខសម្ងាត់');
  String get wrongPin => _('Wrong PIN, try again', 'លេខសម្ងាត់ខុស សូមព្យាយាមម្តងទៀត');
  String get wrongPassword =>
      _('Wrong username or password', 'ឈ្មោះអ្នកប្រើ ឬពាក្យសម្ងាត់ខុស');
  String get accountDisabled =>
      _('That account has been turned off', 'គណនីនេះត្រូវបានបិទ');
  String get username => _('Username', 'ឈ្មោះអ្នកប្រើ');
  String get usernameTaken => _(
        'Another account already uses that username',
        'គណនីផ្សេងកំពុងប្រើឈ្មោះនេះ',
      );
  String get password => _('Password', 'ពាក្យសម្ងាត់');
  String get adminSignIn => _('Owner / admin sign in', 'ម្ចាស់ហាង ចូលប្រើ');
  String get demoCredentials =>
      _('Demo accounts', 'គណនីសាកល្បង');
  String signedInAs(String name) => _('Signed in as $name', 'ចូលជា $name');
  String get browsingAsCustomer =>
      _('Browsing as a customer', 'កំពុងមើលជាអតិថិជន');

  // ------------------------------------------------------------ staff admin
  String get staff => _('Staff', 'បុគ្គលិក');
  String get staffSubtitle => _(
        'Who can use the kitchen and cashier screens',
        'អ្នកណាអាចប្រើផ្ទាំងផ្ទះបាយ និងអ្នកគិតលុយ',
      );
  String get addStaff => _('Add staff', 'បន្ថែមបុគ្គលិក');
  String get editStaff => _('Edit staff', 'កែបុគ្គលិក');
  String get staffName => _('Name', 'ឈ្មោះ');
  String get role => _('Role', 'តួនាទី');
  String get pin => _('PIN', 'លេខសម្ងាត់');
  String get newPin => _('New PIN', 'លេខសម្ងាត់ថ្មី');
  String get newPassword => _('New password', 'ពាក្យសម្ងាត់ថ្មី');
  String get pinRule => _('6 digits', 'លេខ ៦ តួ');
  String get checking => _('Checking…', 'កំពុងពិនិត្យ…');
  String get cannotReachRestaurant => _(
        'Cannot reach the restaurant',
        'មិនអាចភ្ជាប់ទៅភោជនីយដ្ឋានបានទេ',
      );
  String get tryAgain => _('Try again', 'ព្យាយាមម្តងទៀត');
  String get passwordRule =>
      _('At least 8 characters', 'យ៉ាងតិច ៨ តួអក្សរ');
  String get resetPin => _('Reset PIN', 'កំណត់លេខសម្ងាត់ឡើងវិញ');
  String get resetPassword => _('Reset password', 'កំណត់ពាក្យសម្ងាត់ឡើងវិញ');
  String get turnOff => _('Turn off', 'បិទ');
  String get turnOn => _('Turn on', 'បើក');
  String get inactive => _('Turned off', 'បានបិទ');
  String get roleAdminDesc => _(
        'Everything — menu, tables, staff, kitchen and till',
        'គ្រប់យ៉ាង — ម៉ឺនុយ តុ បុគ្គលិក ផ្ទះបាយ និងការទូទាត់',
      );
  String get roleKitchenDesc =>
      _('Kitchen screen only', 'ផ្ទាំងផ្ទះបាយតែប៉ុណ្ណោះ');
  String get roleCashierDesc =>
      _('Payments and invoices only', 'ការទូទាត់ និងវិក្កយបត្រតែប៉ុណ្ណោះ');
  String get pinTaken =>
      _('Another account already uses that PIN', 'គណនីផ្សេងកំពុងប្រើលេខនេះ');
  String get more => _('More', 'ផ្សេងទៀត');
  String get kitchenView => _('Kitchen screen', 'ផ្ទាំងផ្ទះបាយ');
  String get cashierView => _('Cashier screen', 'ផ្ទាំងអ្នកគិតលុយ');
  String staffCount(int count) => count == 1
      ? _('1 account', 'គណនី ១')
      : _('$count accounts', 'គណនី $count');

  // ----------------------------------------------------------------- generic
  String get cancel => _('Cancel', 'បោះបង់');
  String get save => _('Save', 'រក្សាទុក');
  String get delete => _('Delete', 'លុប');
  String get edit => _('Edit', 'កែសម្រួល');
  String get add => _('Add', 'បន្ថែម');
  String get done => _('Done', 'រួចរាល់');
  String get close => _('Close', 'បិទ');
  String get clear => _('Clear', 'សម្អាត');
  String get remove => _('Remove', 'ដកចេញ');
  String get rename => _('Rename', 'ប្តូរឈ្មោះ');
  String get confirm => _('Confirm', 'បញ្ជាក់');
  String get total => _('Total', 'សរុប');
  String get subtotal => _('Subtotal', 'សរុបរង');
  String get quantity => _('Quantity', 'ចំនួន');
  String get price => _('Price', 'តម្លៃ');
  String get optional => _('optional', 'មិនចាំបាច់');
  String get notFound => _('Not found', 'រកមិនឃើញ');

  String table(String number) => _('Table $number', 'តុ $number');
  String orderNo(String number) => _('Order #$number', 'ការបញ្ជាទិញ #$number');
  String itemsCount(int count) => count == 1
      ? _('1 item', 'មុខម្ហូប ១')
      : _('$count items', 'មុខម្ហូប $count');

  // ------------------------------------------------------------ order type
  String get dineIn => _('Dine in', 'ញ៉ាំនៅហាង');
  String get takeaway => _('Takeaway', 'យកទៅផ្ទះ');
  String get orderTypeQuestion =>
      _('Where are you eating?', 'អ្នកនឹងញ៉ាំនៅឯណា?');
  String get dineInBlurb =>
      _('Served to your table', 'បម្រើនៅតុរបស់អ្នក');
  String get takeawayBlurb =>
      _('Packed to go, collect at the counter', 'ខ្ចប់យកទៅ ទទួលនៅបញ្ជរ');
  String get takeawayOrder => _('Takeaway order', 'ការបញ្ជាទិញយកទៅផ្ទះ');
  String get startTakeaway => _('Order takeaway', 'បញ្ជាទិញយកទៅផ្ទះ');
  String get callByNumber => _(
        'We will call your order number at the counter.',
        'យើងនឹងហៅលេខការបញ្ជាទិញរបស់អ្នកនៅបញ្ជរ។',
      );

  // --------------------------------------------------------------- statuses
  String get statusNew => _('New Order', 'ការបញ្ជាទិញថ្មី');
  String get statusInProgress => _('In Progress', 'កំពុងធ្វើ');
  String get statusReady => _('Ready to Serve', 'រួចរាល់បម្រើ');
  String get statusPaid => _('Paid', 'បានទូទាត់');
  String get statusCompleted => _('Completed', 'បញ្ចប់');
  String get statusCancelled => _('Cancelled', 'បានលុបចោល');

  // ------------------------------------------------------------- QR entry
  String get scanTitle =>
      _('Scan the QR code on your table', 'ស្កេនកូដ QR នៅលើតុរបស់អ្នក');
  String get scanBlurb => _(
        'No app, no account. Scanning opens the menu for that table straight '
        'away.',
        'មិនចាំបាច់ដំឡើងកម្មវិធី ឬបង្កើតគណនីទេ។ ស្កេនរួច ម៉ឺនុយសម្រាប់តុនោះនឹងបើកភ្លាមៗ។',
      );
  String get openScanner => _('Open camera scanner', 'បើកកាមេរ៉ាស្កេន');
  String get orTapTable =>
      _('Or tap a table to simulate a scan', 'ឬចុចលើតុដើម្បីសាកល្បងស្កេន');
  String get available => _('Available', 'ទំនេរ');
  String get occupied => _('Occupied', 'មានភ្ញៀវ');

  // -------------------------------------------------------------- scanner
  String get scanTableQr => _('Scan table QR', 'ស្កេន QR របស់តុ');
  String get pointCamera => _(
        'Point the camera at the QR code on your table',
        'តម្រង់កាមេរ៉ាទៅកាន់កូដ QR នៅលើតុរបស់អ្នក',
      );
  String get pickTableInstead => _('Pick a table instead', 'ជ្រើសរើសតុជំនួសវិញ');
  String get unknownCode =>
      _('That code is not one of our tables.', 'កូដនេះមិនមែនជាតុរបស់យើងទេ។');
  String get cameraUnavailable => _('Camera unavailable', 'កាមេរ៉ាមិនអាចប្រើបាន');
  String get cameraHint => _(
        'Use the table list on the previous screen to simulate a scan.',
        'សូមប្រើបញ្ជីតុនៅផ្ទាំងមុន ដើម្បីសាកល្បងស្កេន។',
      );
  String get backToTables => _('Back to tables', 'ត្រឡប់ទៅបញ្ជីតុ');
  String tableNotFound(String number) =>
      _('Table $number was not found', 'រកមិនឃើញតុ $number');
  String get tableNotFoundBlurb => _(
        'This QR code does not belong to any table in this restaurant. Please '
        'ask a member of staff for help.',
        'កូដ QR នេះមិនមែនជារបស់តុណាមួយក្នុងភោជនីយដ្ឋាននេះទេ។ សូមសួរបុគ្គលិកជួយ។',
      );
  String get goToDemo => _('Go to the demo', 'ទៅកាន់ការសាកល្បង');

  // ----------------------------------------------------------- customer menu
  String get menu => _('Menu', 'ម៉ឺនុយ');
  String get popular => _('Popular', 'ពេញនិយម');
  String get cart => _('Cart', 'កន្ត្រក');
  String get myOrder => _('My Order', 'ការបញ្ជាទិញរបស់ខ្ញុំ');

  /// Shorter form for the bottom tab, where the full Khmer phrase overflows.
  String get myOrderTab => _('My Order', 'ការបញ្ជាទិញ');
  String get changeTable => _('Change table', 'ប្តូរតុ');
  String get leaveTableTitle => _('Leave this table?', 'ចាកចេញពីតុនេះ?');
  String get leaveTableBody => _(
        'Your cart will be cleared. Orders you already submitted stay with the '
        'kitchen.',
        'កន្ត្រករបស់អ្នកនឹងត្រូវសម្អាត។ ការបញ្ជាទិញដែលបានផ្ញើរួច នៅតែស្ថិតក្នុងផ្ទះបាយ។',
      );
  String get leaveTable => _('Leave table', 'ចាកចេញពីតុ');
  String get emptyCategory => _('Nothing here yet', 'មិនទាន់មានអ្វីនៅទីនេះទេ');
  String get emptyCategoryBody => _(
        'This category has no dishes at the moment.',
        'ប្រភេទនេះមិនទាន់មានមុខម្ហូបទេ។',
      );
  String get soldOut => _('SOLD OUT', 'អស់ស្តុក');
  String get unavailable => _('Unavailable', 'អស់ស្តុក');
  String get signature => _('Signature', 'មុខម្ហូបពិសេស');
  String addedToCart(String name) =>
      _('$name added to cart', 'បានបន្ថែម $name ទៅកន្ត្រក');
  String off(int percent) => _('$percent% OFF', 'បញ្ចុះ $percent%');

  // ------------------------------------------------------------ food detail
  String get specialRequest => _('Special request', 'សំណើពិសេស');
  String get specialRequestHint =>
      _('e.g. No onion, please (optional)', 'ឧ. សូមកុំដាក់ខ្ទឹមបារាំង (មិនចាំបាច់)');
  String get addToCart => _('Add to Cart', 'បន្ថែមទៅកន្ត្រក');

  // -------------------------------------------------------------------- cart
  String get yourOrder => _('Your Order', 'ការបញ្ជាទិញរបស់អ្នក');
  String get viewOrder => _('View Order', 'មើលការបញ្ជាទិញ');
  String get orderSummary => _('Order summary', 'សង្ខេបការបញ្ជាទិញ');
  String get items => _('Items', 'មុខម្ហូប');
  String get reviewBeforeSubmit => _(
        'Check your items and total, then submit.',
        'សូមពិនិត្យមុខម្ហូប និងតម្លៃសរុប រួចផ្ញើការបញ្ជាទិញ។',
      );
  String get clearCartTitle => _('Clear cart?', 'សម្អាតកន្ត្រក?');
  String get clearCartBody => _(
        'This removes every item you have added.',
        'វានឹងដកមុខម្ហូបទាំងអស់ដែលអ្នកបានបន្ថែម។',
      );
  String get cartEmpty => _('Your cart is empty', 'កន្ត្រករបស់អ្នកទទេ');
  String get cartEmptyBody => _(
        'Add a dish from the menu to get started.',
        'សូមបន្ថែមមុខម្ហូបពីម៉ឺនុយដើម្បីចាប់ផ្តើម។',
      );
  String get browseMenu => _('Browse the menu', 'មើលម៉ឺនុយ');
  String get orderNote => _('Note for the whole order', 'កំណត់ចំណាំសម្រាប់ការបញ្ជាទិញ');
  String get orderNoteHint => _(
        'e.g. Serve the drinks first (optional)',
        'ឧ. សូមបម្រើភេសជ្ជៈមុន (មិនចាំបាច់)',
      );
  String get submitOrder => _('Submit Order', 'ផ្ញើការបញ្ជាទិញ');
  String get editNote => _('Edit note', 'កែកំណត់ចំណាំ');
  String get saveNote => _('Save note', 'រក្សាទុកកំណត់ចំណាំ');
  String get noteHintShort => _('e.g. Less ice', 'ឧ. ទឹកកកតិច');

  // ------------------------------------------------------------ confirmation
  String get sentToKitchen => _(
        'Your order has been sent to the kitchen.',
        'ការបញ្ជាទិញរបស់អ្នកត្រូវបានផ្ញើទៅផ្ទះបាយហើយ។',
      );
  String get trackOrder => _('Track Order', 'តាមដានការបញ្ជាទិញ');
  String get orderSomethingElse => _('Order something else', 'បញ្ជាទិញបន្ថែម');
  String get orderNotFound => _('Order not found', 'រកមិនឃើញការបញ្ជាទិញ');

  // ---------------------------------------------------------------- tracking
  String get noOrdersYet => _('No orders yet', 'មិនទាន់មានការបញ្ជាទិញទេ');
  String get noOrdersYetBody => _(
        'Once you submit an order it will appear here with a live status.',
        'នៅពេលអ្នកផ្ញើការបញ្ជាទិញ វានឹងបង្ហាញនៅទីនេះជាមួយស្ថានភាពបច្ចុប្បន្ន។',
      );
  String get stepReceived => _('Order Received', 'ទទួលបានការបញ្ជាទិញ');
  String get stepCooking => _('Cooking', 'កំពុងចម្អិន');
  String get stepReady => _('Ready to Serve', 'រួចរាល់បម្រើ');
  String get stepWaitingPayment => _('Waiting for Payment', 'រង់ចាំការទូទាត់');
  String get stepPaid => _('Paid', 'បានទូទាត់');
  String get inProgress => _('In progress', 'កំពុងដំណើរការ');
  String get orderCompletedThanks => _(
        'Order completed — thank you!',
        'ការបញ្ជាទិញបានបញ្ចប់ — សូមអរគុណ!',
      );
  String paidBy(String method) => _('Paid by $method', 'ទូទាត់តាម $method');

  // ----------------------------------------------------------------- kitchen
  String get kitchen => _('Kitchen', 'ផ្ទះបាយ');
  String get tabNew => _('New', 'ថ្មី');
  String get tabReady => _('Ready', 'រួចរាល់');
  String ordersInProgress(int count) =>
      _('$count orders in progress', 'ការបញ្ជាទិញកំពុងធ្វើ $count');
  String get startCooking => _('Start Cooking', 'ចាប់ផ្តើមចម្អិន');
  String get readyToServe => _('Ready to Serve', 'រួចរាល់បម្រើ');
  String get noNewOrders => _('No new orders', 'មិនមានការបញ្ជាទិញថ្មីទេ');
  String get noNewOrdersBody => _(
        'New tickets land here the moment a table submits.',
        'សំបុត្រថ្មីនឹងមកដល់ទីនេះភ្លាមៗនៅពេលតុណាមួយផ្ញើការបញ្ជាទិញ។',
      );
  String get nothingReady =>
      _('Nothing waiting to be served', 'មិនមានម្ហូបរង់ចាំបម្រើទេ');
  String get nothingReadyBody => _(
        'Finished dishes appear here until the cashier takes payment.',
        'ម្ហូបដែលចម្អិនរួចនឹងបង្ហាញនៅទីនេះ រហូតដល់អ្នកគិតលុយទទួលប្រាក់។',
      );
  String get handedToCashier => _('Handed to the cashier', 'បញ្ជូនទៅអ្នកគិតលុយ');
  String get waiting => _('Waiting', 'រង់ចាំ');
  String get cooking => _('Cooking', 'កំពុងចម្អិន');
  String get toServe => _('To serve', 'ត្រូវបម្រើ');
  String get cookedToday => _('Cooked today', 'បានចម្អិនថ្ងៃនេះ');
  String dishesCount(int count) => count == 1
      ? _('1 dish', 'មុខម្ហូប ១')
      : _('$count dishes', 'មុខម្ហូប $count');

  // ----------------------------------------------------------------- cashier
  String takenToday(String amount) =>
      _('Taken today: $amount', 'ទទួលបានថ្ងៃនេះ៖ $amount');
  String readyForPayment(int count) =>
      _('Ready for Payment ($count)', 'រង់ចាំទូទាត់ ($count)');
  String get completed => _('Completed', 'បញ្ចប់');
  String get noPayable =>
      _('No orders waiting to pay', 'មិនមានការបញ្ជាទិញរង់ចាំទូទាត់ទេ');
  String get noPayableBody => _(
        'Orders appear here as soon as the kitchen marks them ready to serve.',
        'ការបញ្ជាទិញនឹងបង្ហាញនៅទីនេះ ភ្លាមៗនៅពេលផ្ទះបាយសម្គាល់ថារួចរាល់បម្រើ។',
      );
  String get nothingSettled => _('Nothing settled yet', 'មិនទាន់មានការទូទាត់ទេ');
  String get nothingSettledBody => _(
        'Paid orders and their invoices are listed here.',
        'ការបញ្ជាទិញដែលបានទូទាត់ និងវិក្កយបត្រ បង្ហាញនៅទីនេះ។',
      );
  String get paymentMethod => _('Payment method', 'វិធីទូទាត់');
  String get collectPayment => _('Collect Payment', 'ទទួលការទូទាត់');
  String get confirmPayment => _('Confirm Payment', 'បញ្ជាក់ការទូទាត់');
  String get viewInvoice => _('View Invoice', 'មើលវិក្កយបត្រ');
  String paidWith(String method, String time) =>
      _('Paid — $method  ·  $time', 'ទូទាត់ — $method  ·  $time');

  // ------------------------------------------------- cashier: live & cancel
  String get liveOrders => _('Live', 'កំពុងដំណើរការ');
  String get liveOrdersCount =>
      _('Every order in the restaurant right now', 'ការបញ្ជាទិញទាំងអស់ក្នុងហាងឥឡូវនេះ');
  String get toPay => _('To pay', 'ត្រូវទូទាត់');
  String get closed => _('Closed', 'បានបិទ');
  String get nothingLive => _('Nothing cooking', 'មិនមានអ្វីកំពុងធ្វើទេ');
  String get nothingLiveBody => _(
        'Orders show up here the moment a customer sends them, and stay until '
        'they are paid.',
        'ការបញ្ជាទិញនឹងបង្ហាញនៅទីនេះភ្លាមៗនៅពេលអតិថិជនផ្ញើ ហើយនៅរហូតដល់បានទូទាត់។',
      );
  String get cancelOrder => _('Cancel order', 'លុបការបញ្ជាទិញ');
  String cancelOrderTitle(String number) =>
      _('Cancel order #$number?', 'លុបការបញ្ជាទិញ #$number?');
  String get cancelOrderBody => _(
        'The order is dropped and the table is freed. This cannot be undone.',
        'ការបញ្ជាទិញនឹងត្រូវលុបចោល ហើយតុនឹងទំនេរវិញ។ មិនអាចត្រឡប់វិញបានទេ។',
      );
  String get keepOrder => _('Keep it', 'រក្សាទុក');
  String orderCancelled(String number) =>
      _('Order #$number cancelled', 'បានលុបការបញ្ជាទិញ #$number');
  String get cancelTooLate => _(
        'The kitchen has already started cooking this one.',
        'ផ្ទះបាយបានចាប់ផ្តើមចម្អិនរួចហើយ។',
      );
  String cancelledBy(String name) => _('Cancelled by $name', 'លុបដោយ $name');
  String get editItems => _('Edit items', 'កែមុខម្ហូប');
  String get editItemsBody => _(
        'Change a quantity, or take a dish off the order. Only while the '
        'kitchen has not started.',
        'ប្តូរចំនួន ឬដកមុខម្ហូបចេញពីការបញ្ជាទិញ។ បានតែពេលផ្ទះបាយមិនទាន់ចាប់ផ្តើម។',
      );
  String get removeDish => _('Remove', 'ដកចេញ');
  String dishRemoved(String name) => _('$name removed', 'បានដក $name ចេញ');
  String get orderUpdated => _('Order updated', 'បានកែការបញ្ជាទិញ');
  String get cannotEditNow => _(
        'This order can no longer be changed.',
        'ការបញ្ជាទិញនេះមិនអាចកែបានទៀតទេ។',
      );
  String get orderWasCancelled => _(
        'This order was cancelled.',
        'ការបញ្ជាទិញនេះត្រូវបានលុបចោល។',
      );
  String get askCashier => _(
        'Ask the cashier if you need it back.',
        'សូមសួរអ្នកគិតលុយ ប្រសិនបើអ្នកចង់បានវាវិញ។',
      );

  // ------------------------------------------------ cashier: order for guest
  String get newOrder => _('New order', 'ការបញ្ជាទិញថ្មី');
  String get orderForCustomer =>
      _('Order for a customer', 'បញ្ជាទិញជំនួសអតិថិជន');
  String get orderForCustomerBody => _(
        'Take an order at the counter and send it straight to the kitchen.',
        'ទទួលការបញ្ជាទិញនៅបញ្ជរ ហើយផ្ញើទៅផ្ទះបាយភ្លាម។',
      );
  String get whereIsItGoing => _('Where is it going?', 'ទៅកន្លែងណា?');
  String get chooseTable => _('Choose a table', 'ជ្រើសរើសតុ');
  String get pickTableToDineIn => _(
        'Dine-in orders need a table number.',
        'ការបញ្ជាទិញញ៉ាំនៅហាង ត្រូវការលេខតុ។',
      );
  String get noTableChosen => _('No table chosen', 'មិនទាន់ជ្រើសរើសតុ');
  String get tapDishToAdd =>
      _('Tap a dish to add it', 'ចុចលើមុខម្ហូបដើម្បីបន្ថែម');
  String get nothingAddedYet => _('Nothing added yet', 'មិនទាន់បន្ថែមអ្វីទេ');
  String get sendToKitchen => _('Send to kitchen', 'ផ្ញើទៅផ្ទះបាយ');
  String orderPlaced(String number) =>
      _('Order #$number sent to the kitchen', 'បានផ្ញើការបញ្ជាទិញ #$number ទៅផ្ទះបាយ');
  String placedBy(String name) => _('Taken by $name', 'ទទួលដោយ $name');

  // ----------------------------------------------------------------- invoice
  String get invoice => _('Invoice', 'វិក្កយបត្រ');
  /// Short label for the receipt, where `orderNote` is far too long.
  String get note => _('Note', 'កំណត់ចំណាំ');
  String get printInvoice => _('Print Invoice', 'បោះពុម្ពវិក្កយបត្រ');
  String get doneCloseTable => _('Done — close the table', 'រួចរាល់ — បិទតុ');
  String get payment => _('Payment', 'ការទូទាត់');
  String get unpaid => _('Unpaid', 'មិនទាន់ទូទាត់');
  String get thankYou => _('Thank you!', 'សូមអរគុណ!');
  String get invoiceNotFound => _('Invoice not found', 'រកមិនឃើញវិក្កយបត្រ');
  String get discountLine => _('Discount', 'បញ្ចុះតម្លៃ');

  // --------------------------------------------------------------- admin nav
  String get dashboard => _('Dashboard', 'ផ្ទាំងគ្រប់គ្រង');
  String get orders => _('Orders', 'ការបញ្ជាទិញ');
  String get tables => _('Tables', 'តុ');
  String get settings => _('Settings', 'ការកំណត់');

  // --------------------------------------------------------- admin dashboard
  String get todaysSummary => _("Today's summary", 'សង្ខេបថ្ងៃនេះ');
  String get revenue => _('Revenue', 'ចំណូល');
  String get pending => _('Pending', 'កំពុងរង់ចាំ');
  String get recentOrders => _('Recent orders', 'ការបញ្ជាទិញថ្មីៗ');
  String get noOrdersToday => _('No orders yet today.', 'មិនទាន់មានការបញ្ជាទិញថ្ងៃនេះទេ។');
  String totalCount(int count) => _('$count in total', 'សរុប $count');
  String get all => _('All', 'ទាំងអស់');
  String get noOrdersHere => _('No orders here', 'មិនមានការបញ្ជាទិញនៅទីនេះទេ');
  String get noOrdersHereBody =>
      _('Try a different status filter.', 'សូមសាកល្បងតម្រងស្ថានភាពផ្សេង។');

  // -------------------------------------------------------------- admin menu
  String menuSummary(int dishes, int categories) => _(
        '$dishes dishes in $categories categories',
        'មុខម្ហូប $dishes ក្នុង $categories ប្រភេទ',
      );
  String get category => _('Category', 'ប្រភេទ');
  String get addDish => _('Add dish', 'បន្ថែមមុខម្ហូប');
  String get editDish => _('Edit dish', 'កែមុខម្ហូប');
  String get dishName => _('Dish name', 'ឈ្មោះមុខម្ហូប');
  String get enterDishName => _('Give the dish a name', 'សូមដាក់ឈ្មោះមុខម្ហូប');
  String get enterPrice => _('Enter a price', 'សូមបញ្ចូលតម្លៃ');
  String get dishNameKm => _('Dish name (Khmer)', 'ឈ្មោះជាភាសាខ្មែរ');
  String get english => _('English', 'អង់គ្លេស');
  String get khmer => _('Khmer', 'ខ្មែរ');
  String get name => _('Name', 'ឈ្មោះ');
  String get description => _('Description', 'ការពិពណ៌នា');
  String get descriptionKm => _('Description (Khmer)', 'ការពិពណ៌នាជាភាសាខ្មែរ');
  String get khmerFallbackHint => _(
        'Customers see whichever language they picked. Leave the Khmer boxes '
        'blank to fall back to the English text.',
        'អតិថិជននឹងឃើញភាសាដែលពួកគេជ្រើសរើស។ ទុកប្រអប់ខ្មែរឲ្យទទេ '
        'ដើម្បីប្រើអត្ថបទអង់គ្លេសជំនួស។',
      );
  String get needsKhmer => _('Needs Khmer', 'ត្រូវការភាសាខ្មែរ');
  String khmerMissing(int count) => count == 1
      ? _('1 item still needs Khmer', 'មុខម្ហូប ១ ត្រូវការភាសាខ្មែរ')
      : _('$count items still need Khmer',
          'មុខម្ហូប $count ត្រូវការភាសាខ្មែរ');
  String get allTranslated =>
      _('Every item has Khmer', 'មុខម្ហូបទាំងអស់មានភាសាខ្មែរ');
  String get restaurantNameKm =>
      _('Restaurant name (Khmer)', 'ឈ្មោះជាភាសាខ្មែរ');
  String get discountPercent => _('Discount %', 'បញ្ចុះតម្លៃ %');
  String get noDiscount => _('No discount', 'គ្មានការបញ្ចុះតម្លៃ');
  String customerPays(String amount) =>
      _('Customer pays $amount', 'អតិថិជនបង់ $amount');
  String get image => _('Image', 'រូបភាព');
  String get uploadPhoto => _('Upload photo', 'ផ្ទុករូបភាព');
  String get takePhoto => _('Take photo', 'ថតរូប');
  String get removePhoto => _('Remove photo', 'ដករូបភាពចេញ');
  String get orPickIllustration =>
      _('Or pick a bundled illustration', 'ឬជ្រើសរើសរូបភាពដែលមានស្រាប់');
  String get photoTooLarge => _(
        'That photo is too large — try a smaller one.',
        'រូបភាពនេះធំពេក — សូមសាកល្បងរូបតូចជាង។',
      );
  String get photoFailed => _('Could not read that photo.', 'មិនអាចអានរូបភាពនេះបានទេ។');
  String get availableToggle => _('Available', 'មានលក់');
  String get availableOn => _(
        'Customers can order this dish',
        'អតិថិជនអាចបញ្ជាទិញមុខម្ហូបនេះបាន',
      );
  String get availableOff => _(
        'Shown as Sold Out and cannot be ordered',
        'បង្ហាញថាអស់ស្តុក ហើយមិនអាចបញ្ជាទិញបានទេ',
      );
  String get showInPopular => _('Show in Popular', 'បង្ហាញក្នុងពេញនិយម');
  String get showInPopularBody =>
      _('Appears on the first tab of the menu', 'បង្ហាញនៅផ្ទាំងទីមួយនៃម៉ឺនុយ');
  String get signatureDish => _('Signature dish', 'មុខម្ហូបពិសេស');
  String get signatureDishBody => _(
        'Marked with a star as a house special',
        'សម្គាល់ដោយផ្កាយ ជាមុខម្ហូបពិសេសរបស់ហាង',
      );
  String get saveChanges => _('Save changes', 'រក្សាទុកការកែប្រែ');
  String get addCategory => _('Add category', 'បន្ថែមប្រភេទ');
  String get renameCategory => _('Rename category', 'ប្តូរឈ្មោះប្រភេទ');
  String get deleteCategory => _('Delete category', 'លុបប្រភេទ');
  String get categoryNameKm => _('Name in Khmer', 'ឈ្មោះជាភាសាខ្មែរ');
  String get categoryHint => _('e.g. Soups', 'ឧ. ស៊ុប');
  String get createCategoryFirst =>
      _('Create a category first', 'សូមបង្កើតប្រភេទជាមុនសិន');
  String get noCategories => _('No categories yet', 'មិនទាន់មានប្រភេទទេ');
  String get noCategoriesBody => _(
        'Add a category before adding dishes.',
        'សូមបន្ថែមប្រភេទមុននឹងបន្ថែមមុខម្ហូប។',
      );
  String get noDishesInCategory => _(
        'No dishes in this category yet.',
        'មិនទាន់មានមុខម្ហូបក្នុងប្រភេទនេះទេ។',
      );
  String deleteDishTitle(String name) => _('Delete $name?', 'លុប $name?');
  String get deleteDishBody => _(
        'It will disappear from the customer menu.',
        'វានឹងបាត់ពីម៉ឺនុយអតិថិជន។',
      );
  String deleteCategoryTitle(String name) => _('Delete $name?', 'លុប $name?');
  String get deleteCategoryEmpty =>
      _('This category is empty.', 'ប្រភេទនេះទទេ។');
  String deleteCategoryBody(int count) => _(
        'This also deletes the $count dishes filed under it.',
        'វានឹងលុបមុខម្ហូប $count ដែលនៅក្នុងប្រភេទនេះផងដែរ។',
      );
  String addDishTo(String category) =>
      _('Add dish to $category', 'បន្ថែមមុខម្ហូបទៅ $category');

  // ------------------------------------------------------------ admin tables
  String get tablesAndQr => _('Tables & QR', 'តុ និង QR');
  String tablesSummary(int count, int occupied) => _(
        '$count tables  ·  $occupied occupied',
        'តុ $count  ·  មានភ្ញៀវ $occupied',
      );
  String get addTable => _('Add table', 'បន្ថែមតុ');
  String tableAdded(String name) => _('$name added', 'បានបន្ថែម $name');
  String get renameTable => _('Rename table', 'ប្តូរឈ្មោះតុ');
  String get tableNameHint => _('e.g. Terrace 01', 'ឧ. រានហាល ០១');
  String get noTables => _('No tables yet', 'មិនទាន់មានតុទេ');
  String get noTablesBody => _(
        'Add a table to generate its QR code.',
        'បន្ថែមតុ ដើម្បីបង្កើតកូដ QR របស់វា។',
      );
  String deleteTableTitle(String name) => _('Delete $name?', 'លុប $name?');
  String get deleteTableBody => _(
        'Its QR code stops working immediately.',
        'កូដ QR របស់វានឹងឈប់ដំណើរការភ្លាមៗ។',
      );
  String get tableBusy => _(
        'This table still has an active order',
        'តុនេះនៅមានការបញ្ជាទិញកំពុងដំណើរការ',
      );
  String get viewQr => _('View QR', 'មើល QR');

  // ---------------------------------------------------------------- qr sheet
  String get tableQrCode => _('Table QR code', 'កូដ QR របស់តុ');
  String get scanToOrder => _('Scan to Order', 'ស្កេនដើម្បីបញ្ជាទិញ');
  String get encodedValue => _('Encoded value', 'តម្លៃដែលបានអ៊ិនកូដ');
  String get qrNotScannable => _(
        'This code cannot be scanned by a customer',
        'អតិថិជនមិនអាចស្កេនកូដនេះបានទេ',
      );
  String get qrNotScannableBody => _(
        'It carries a table identifier, not a web address, so a phone camera '
        'will do nothing with it. Build the app with PUBLIC_URL set to where '
        'the customer web app is hosted, then print these again.',
        'វាផ្ទុកតែលេខសម្គាល់តុ មិនមែនអាសយដ្ឋានគេហទំព័រទេ ដូច្នេះកាមេរ៉ាទូរស័ព្ទនឹងមិនធ្វើអ្វីឡើយ។ '
        'សូមបង្កើតកម្មវិធីជាមួយ PUBLIC_URL ដែលជាកន្លែងដាក់កម្មវិធីសម្រាប់អតិថិជន រួចបោះពុម្ពម្តងទៀត។',
      );
  String identifier(String value) => _('Identifier: $value', 'អត្តសញ្ញាណ៖ $value');
  String get download => _('Download', 'ទាញយក');
  String get printQr => _('Print QR', 'បោះពុម្ព QR');

  // ---------------------------------------------------------------- settings
  String get settingsSubtitle => _(
        'Restaurant profile and payments',
        'ព័ត៌មានភោជនីយដ្ឋាន និងការទូទាត់',
      );
  String get restaurant => _('Restaurant', 'ភោជនីយដ្ឋាន');
  String get logo => _('Logo', 'និមិត្តសញ្ញា');
  String get restaurantName => _('Restaurant name', 'ឈ្មោះភោជនីយដ្ឋាន');
  String get phoneNumber => _('Phone number', 'លេខទូរស័ព្ទ');
  String get address => _('Address', 'អាសយដ្ឋាន');
  String get currency => _('Currency', 'រូបិយប័ណ្ណ');
  String get symbol => _('Symbol', 'និមិត្តសញ្ញា');
  String get code => _('Code', 'កូដ');
  String get paymentMethods => _('Payment methods', 'វិធីទូទាត់');
  String get addPaymentMethod => _('Add payment method', 'បន្ថែមវិធីទូទាត់');
  String get paymentMethodHint => _('e.g. Bakong', 'ឧ. បាគង');
  String get saveSettings => _('Save settings', 'រក្សាទុកការកំណត់');
  String get settingsSaved => _('Settings saved', 'បានរក្សាទុកការកំណត់');
  String get needName => _('The restaurant needs a name', 'ភោជនីយដ្ឋានត្រូវការឈ្មោះ');
  String get needMethod => _(
        'Keep at least one payment method',
        'សូមរក្សាទុកវិធីទូទាត់យ៉ាងតិចមួយ',
      );
  String get noMethods => _(
        'No payment methods — the cashier cannot take payment.',
        'គ្មានវិធីទូទាត់ — អ្នកគិតលុយមិនអាចទទួលប្រាក់បានទេ។',
      );
  String get prototype => _('Prototype', 'គំរូសាកល្បង');
  String get resetDemo => _('Reset demo data', 'កំណត់ទិន្នន័យសាកល្បងឡើងវិញ');
  String get resetDemoBody => _(
        'Restores the sample menu, tables and orders, and clears anything '
        'created during this demo.',
        'ស្តារម៉ឺនុយ តុ និងការបញ្ជាទិញគំរូ ហើយលុបអ្វីដែលបានបង្កើតក្នុងការសាកល្បងនេះ។',
      );
  String get resetDemoTitle => _('Reset demo data?', 'កំណត់ទិន្នន័យសាកល្បងឡើងវិញ?');
  String get resetDemoConfirm => _(
        'Every order, menu change and table change made in this session will '
        'be discarded.',
        'រាល់ការបញ្ជាទិញ ការកែម៉ឺនុយ និងការកែតុក្នុងវគ្គនេះនឹងត្រូវលុបចោល។',
      );
  String get reset => _('Reset', 'កំណត់ឡើងវិញ');
  String get demoRestored => _('Demo data restored', 'បានស្តារទិន្នន័យសាកល្បង');
}
