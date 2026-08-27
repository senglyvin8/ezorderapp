import '../config/app_config.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/plan.dart';
import '../models/restaurant_settings.dart';
import '../models/restaurant_table.dart';
import '../models/staff_account.dart';

/// Seed content for the prototype: ABC Restaurant, ten tables, a small menu
/// and a day's worth of orders spread across every status so the Kitchen,
/// Cashier and Admin screens look realistic on first launch.
class DemoData {
  const DemoData._();

  static const int firstOrderNumber = Seed.firstOrderNumber;

  /// The restaurant's identity, straight from [Brand] in
  /// `lib/config/app_config.dart`.
  static RestaurantSettings settings() => const RestaurantSettings(
        // The showcase runs on PRO: it seeds ten tables, and a demo that
        // cannot add an eleventh teaches the wrong thing about the product.
        plan: Plan.pro,
        name: Brand.name,
        nameKm: Brand.nameKm,
        logo: Brand.logo,
        phone: Brand.phone,
        address: Brand.address,
        currencySymbol: Brand.currencySymbol,
        currencyCode: Brand.currencyCode,
        paymentMethods: Brand.paymentMethods,
      );

  /// Seed accounts. The credentials are printed on the sign-in screen so the
  /// prototype can be opened by anyone; a real deployment would force a
  /// password change on first run.
  static const String adminUsername = Seed.adminUsername;
  static const String adminPassword = Seed.adminPassword;
  static const String kitchenName = Seed.kitchenName;
  static const String cashierName = Seed.cashierName;
  static const String kitchenPin = Seed.kitchenPin;
  static const String cashierPin = Seed.cashierPin;

  static List<StaffAccount> accounts() => [
        StaffAccount.create(
          id: 'staff-admin',
          name: Seed.adminDisplayName,
          role: StaffRole.admin,
          username: adminUsername,
          secret: adminPassword,
        ),
        StaffAccount.create(
          id: 'staff-kitchen',
          name: kitchenName,
          role: StaffRole.kitchen,
          secret: kitchenPin,
        ),
        StaffAccount.create(
          id: 'staff-cashier',
          name: cashierName,
          role: StaffRole.cashier,
          secret: cashierPin,
        ),
      ];

  static List<MenuCategory> categories() => const [
        MenuCategory(
            id: 'cat-rice', name: 'Rice', nameKm: 'បាយ', sortOrder: 1),
        MenuCategory(
            id: 'cat-noodles', name: 'Noodles', nameKm: 'មី និងគុយទាវ',
            sortOrder: 2),
        MenuCategory(
            id: 'cat-drinks', name: 'Drinks', nameKm: 'ភេសជ្ជៈ', sortOrder: 3),
        MenuCategory(
            id: 'cat-dessert', name: 'Dessert', nameKm: 'បង្អែម', sortOrder: 4),
      ];

  static List<MenuItem> menuItems() => const [
        MenuItem(
          id: 'food-01',
          name: 'Chicken Fried Rice',
          nameKm: 'បាយឆាសាច់មាន់',
          description: 'Fried rice with chicken and vegetables.',
          descriptionKm: 'បាយឆាជាមួយសាច់មាន់ និងបន្លែ',
          price: 3.50,
          categoryId: 'cat-rice',
          image: 'chicken_fried_rice',
          popular: true,
        ),
        MenuItem(
          id: 'food-02',
          name: 'Beef Fried Rice',
          nameKm: 'បាយឆាសាច់គោ',
          description: 'Wok-fried rice with sliced beef and egg.',
          descriptionKm: 'បាយឆាសាច់គោចិញ្ច្រាំ ជាមួយពងមាន់',
          price: 4.00,
          categoryId: 'cat-rice',
          image: 'beef_fried_rice',
          popular: true,
        ),
        MenuItem(
          id: 'food-03',
          name: 'Pork Rice',
          nameKm: 'បាយសាច់ជ្រូក',
          description: 'Grilled pork over steamed rice with pickles.',
          descriptionKm: 'សាច់ជ្រូកអាំង ជាមួយបាយ និងជ្រក់',
          price: 3.50,
          categoryId: 'cat-rice',
          image: 'pork_rice',
        ),
        MenuItem(
          id: 'food-04',
          name: 'Beef Noodles',
          nameKm: 'គុយទាវសាច់គោ',
          description: 'Rice noodles in beef broth with herbs.',
          descriptionKm: 'គុយទាវក្នុងទឹកស៊ុបសាច់គោ ជាមួយបន្លែក្រអូប',
          price: 4.00,
          categoryId: 'cat-noodles',
          image: 'beef_noodles',
          popular: true,
        ),
        MenuItem(
          id: 'food-05',
          name: 'Chicken Noodles',
          nameKm: 'មីសាច់មាន់',
          description: 'Egg noodles with shredded chicken and greens.',
          descriptionKm: 'មីពងមាន់ជាមួយសាច់មាន់ហែក និងបន្លែ',
          price: 3.50,
          categoryId: 'cat-noodles',
          image: 'chicken_noodles',
        ),
        MenuItem(
          id: 'food-06',
          name: 'Iced Latte',
          nameKm: 'កាហ្វេឡាតេទឹកកក',
          description: 'Espresso with fresh milk over ice.',
          descriptionKm: 'កាហ្វេអេស្ព្រេសូ ជាមួយទឹកដោះគោស្រស់ និងទឹកកក',
          price: 2.50,
          categoryId: 'cat-drinks',
          image: 'iced_latte',
          popular: true,
        ),
        MenuItem(
          id: 'food-07',
          name: 'Coca Cola',
          nameKm: 'កូកាកូឡា',
          description: 'Chilled 330ml can.',
          descriptionKm: 'កំប៉ុងត្រជាក់ ៣៣០ ម.ល',
          price: 1.50,
          categoryId: 'cat-drinks',
          image: 'coca_cola',
        ),
        MenuItem(
          id: 'food-08',
          name: 'Iced Tea',
          nameKm: 'តែទឹកកក',
          description: 'House brewed tea, lightly sweetened.',
          descriptionKm: 'តែដាំផ្ទាល់ ផ្អែមល្មម',
          price: 1.50,
          categoryId: 'cat-drinks',
          image: 'iced_tea',
        ),
        MenuItem(
          id: 'food-09',
          name: 'Mango Sticky Rice',
          nameKm: 'បាយដំណើបស្វាយ',
          description: 'Sweet coconut sticky rice with ripe mango.',
          descriptionKm: 'បាយដំណើបទឹកដូង ជាមួយស្វាយទុំ',
          price: 3.00,
          categoryId: 'cat-dessert',
          image: 'mango_sticky_rice',
          popular: true,
        ),
      ];

  static List<RestaurantTable> tables() =>
      List.generate(Seed.tableCount, (i) {
        final number = (i + 1).toString().padLeft(2, '0');
        return RestaurantTable(
          id: 'table-$number',
          number: number,
          name: 'Table $number',
          qrId: RestaurantTable.qrIdFor(number),
        );
      });

  /// Images an admin can pick from when adding or editing a dish.
  static const List<String> imageChoices = [
    'chicken_fried_rice',
    'beef_fried_rice',
    'pork_rice',
    'beef_noodles',
    'chicken_noodles',
    'iced_latte',
    'coca_cola',
    'iced_tea',
    'mango_sticky_rice',
    'placeholder',
  ];

  /// Demo orders, timed relative to [now] so the day always looks current.
  static List<Order> orders(DateTime now) {
    final items = {for (final m in menuItems()) m.id: m};

    Order build({
      required int number,
      required String tableNumber,
      required List<(String, int, String?)> lines,
      required OrderStatus status,
      required int minutesAgo,
      String? paymentMethod,
      int? paidMinutesAgo,
      String? customerNote,
    }) {
      final orderItems = <OrderItem>[];
      for (var i = 0; i < lines.length; i++) {
        final (foodId, qty, note) = lines[i];
        final food = items[foodId]!;
        orderItems.add(OrderItem(
          id: 'oi-$number-$i',
          foodId: food.id,
          name: food.name,
          price: food.price,
          quantity: qty,
          note: note,
        ));
      }
      final subtotal = orderItems.fold<double>(0, (s, i) => s + i.lineTotal);
      return Order(
        id: 'order-$number',
        orderNumber: '$number',
        tableId: 'table-$tableNumber',
        tableNumber: tableNumber,
        items: orderItems,
        subtotal: subtotal,
        total: subtotal,
        customerNote: customerNote,
        status: status,
        paymentMethod: paymentMethod,
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
        paidAt: paidMinutesAgo == null
            ? null
            : now.subtract(Duration(minutes: paidMinutesAgo)),
      );
    }

    return [
      build(
        number: 101,
        tableNumber: '03',
        lines: [('food-02', 2, null), ('food-06', 2, 'Less ice')],
        status: OrderStatus.completed,
        minutesAgo: 195,
        paymentMethod: 'Cash',
        paidMinutesAgo: 168,
      ),
      build(
        number: 102,
        tableNumber: '01',
        lines: [('food-04', 1, null), ('food-08', 1, null)],
        status: OrderStatus.completed,
        minutesAgo: 180,
        paymentMethod: 'KHQR',
        paidMinutesAgo: 152,
      ),
      build(
        number: 103,
        tableNumber: '06',
        lines: [('food-01', 3, 'No onion'), ('food-07', 3, null)],
        status: OrderStatus.completed,
        minutesAgo: 154,
        paymentMethod: 'Cash',
        paidMinutesAgo: 126,
      ),
      build(
        number: 104,
        tableNumber: '02',
        lines: [('food-05', 2, null), ('food-09', 1, null)],
        status: OrderStatus.completed,
        minutesAgo: 132,
        paymentMethod: 'Card',
        paidMinutesAgo: 108,
      ),
      build(
        number: 105,
        tableNumber: '08',
        lines: [('food-03', 2, null), ('food-06', 1, null)],
        status: OrderStatus.completed,
        minutesAgo: 111,
        paymentMethod: 'KHQR',
        paidMinutesAgo: 86,
      ),
      build(
        number: 106,
        tableNumber: '04',
        lines: [('food-01', 1, null), ('food-04', 1, 'Extra herbs')],
        status: OrderStatus.completed,
        minutesAgo: 94,
        paymentMethod: 'Cash',
        paidMinutesAgo: 70,
      ),
      build(
        number: 107,
        tableNumber: '10',
        lines: [('food-02', 1, null), ('food-09', 2, null)],
        status: OrderStatus.completed,
        minutesAgo: 76,
        paymentMethod: 'Cash',
        paidMinutesAgo: 55,
      ),
      build(
        number: 108,
        tableNumber: '05',
        lines: [('food-05', 1, null), ('food-08', 2, 'No sugar')],
        status: OrderStatus.completed,
        minutesAgo: 58,
        paymentMethod: 'KHQR',
        paidMinutesAgo: 40,
      ),
      build(
        number: 109,
        tableNumber: '09',
        lines: [('food-02', 2, null), ('food-07', 2, null)],
        status: OrderStatus.paid,
        minutesAgo: 41,
        paymentMethod: 'Cash',
        paidMinutesAgo: 6,
      ),
      build(
        number: 110,
        tableNumber: '03',
        lines: [('food-01', 2, 'No onion'), ('food-06', 1, 'Less ice')],
        status: OrderStatus.ready,
        minutesAgo: 22,
        customerNote: 'We are in a hurry, thank you.',
      ),
      build(
        number: 111,
        tableNumber: '07',
        lines: [('food-04', 2, null), ('food-09', 1, null)],
        status: OrderStatus.cooking,
        minutesAgo: 11,
      ),
      build(
        number: 112,
        tableNumber: '02',
        lines: [('food-03', 1, 'Spicy please'), ('food-08', 1, null)],
        status: OrderStatus.newOrder,
        minutesAgo: 3,
      ),
    ];
  }

  static int nextOrderNumber() => 113;
}
