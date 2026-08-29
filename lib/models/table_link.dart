import 'package:flutter/widgets.dart';

/// A scanned table QR code, taken apart.
///
/// The link carries two things and the app needs both: which restaurant, and
/// which table. `/order/<slug>/table/05`, or the older `/restaurant/...` form
/// that some printed codes still carry.
///
/// Parsed in one place because two very different callers read the same link
/// and must agree about it — the router, which decides what to show, and the
/// bootstrap, which decides whose restaurant to open before there is a router
/// at all. They used to read it separately, and only one of them read the
/// slug.
class TableLink {
  const TableLink({required this.slug, required this.tableNumber});

  /// The restaurant the sticker belongs to.
  final String slug;

  /// As printed, which may be `5` where the table is `05`.
  final String tableNumber;

  /// Null when [route] is not a table link — every other path in the app.
  static TableLink? parse(String? route) {
    final segments = Uri.parse(route ?? '/').pathSegments;
    if (segments.length != 4) return null;
    if (segments[0] != 'order' && segments[0] != 'restaurant') return null;
    if (segments[2] != 'table') return null;

    final slug = segments[1].trim().toLowerCase();
    final number = segments[3].trim();
    // A link naming no restaurant or no table is not a table link, whatever
    // its shape. Treating it as one would open somebody's restaurant on a
    // guess.
    if (slug.isEmpty || number.isEmpty) return null;

    return TableLink(slug: slug, tableNumber: number);
  }

  /// The link this app was launched with, when a camera opened it.
  ///
  /// Read from the platform rather than the router because the bootstrap needs
  /// it before the first route exists — it is what decides whether the diner
  /// sees a menu or a device-setup screen.
  static TableLink? ofLaunch() => parse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      );
}
