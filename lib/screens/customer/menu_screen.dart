import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/cart_summary_bar.dart';
import '../../widgets/food_image.dart';
import '../../widgets/table_picker.dart';
import 'food_detail_sheet.dart';

/// Mobile-first menu: restaurant header, category strip, dish cards.
class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.onOpenCart,
    required this.onLeaveTable,
  });

  final VoidCallback onOpenCart;
  final VoidCallback onLeaveTable;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

/// One category of the menu as it appears in the scrolling list.
class _MenuSection {
  const _MenuSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<MenuItem> items;
}

class _MenuScreenState extends State<MenuScreen> {
  /// A header counts as "the one you are reading" once its top edge has
  /// reached this far from the top of the list.
  static const double _headerSnap = 12;

  final ScrollController _scroll = ScrollController();
  final ScrollController _chipScroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Map<String, GlobalKey> _headerKeys = {};
  final Map<String, GlobalKey> _chipKeys = {};

  List<_MenuSection> _sections = const [];
  String _categoryId = kPopularCategoryId;

  /// Blank space under the last dish. Without it the categories near the end
  /// of the menu can never be scrolled up to the top of the list, so tapping
  /// their tab would leave the reader looking at the wrong heading.
  double _tail = _minTail;
  static const double _minTail = 28;

  /// True while a tap on a chip is driving the list, so the scroll-spy does
  /// not fight the animation and light up every tab it passes through.
  bool _scrollingToSection = false;
  bool _syncQueued = false;

  /// The section a tap is currently heading for. A second tap takes it over,
  /// and the run it interrupted gives up rather than dragging the list back.
  String? _scrollTarget;

  @override
  void dispose() {
    _scroll.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  GlobalKey _headerKey(String id) =>
      _headerKeys.putIfAbsent(id, () => GlobalKey());

  GlobalKey _chipKey(String id) => _chipKeys.putIfAbsent(id, () => GlobalKey());

  /// Recompute the highlighted tab after the frame that the scroll produced —
  /// header positions are only trustworthy once that layout has happened.
  void _queueSync() {
    if (_syncQueued) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (!mounted) return;
      _syncTail();
      // A tap already knows which tab it wants; only a finger on the list
      // gets to move the highlight.
      if (!_scrollingToSection) _syncActiveCategory();
    });
  }

  /// Distance from the top of the list to the top of a section header, or
  /// null when that header is too far off screen to have been built.
  double? _headerTop(String id) {
    final list = _listKey.currentContext?.findRenderObject();
    final header = _headerKeys[id]?.currentContext?.findRenderObject();
    if (list is! RenderBox || header is! RenderBox) return null;
    if (!list.attached || !header.attached) return null;
    return list.globalToLocal(header.localToGlobal(Offset.zero)).dy;
  }

  /// Size the tail so the last category can still reach the top of the list.
  /// Measured rather than guessed: the height of a section depends on how many
  /// dishes it holds and how long their names run in the current language.
  void _syncTail() {
    if (_sections.isEmpty || !_scroll.hasClients) return;
    final lastTop = _headerTop(_sections.last.id);
    if (lastTop == null) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) {
      // The whole menu fits on one screen — there is nothing to scroll and
      // nothing to pad, and the total height cannot be read off the extent.
      if (_tail != _minTail) setState(() => _tail = _minTail);
      return;
    }
    // Everything below the last heading, with the tail already there taken
    // back out — otherwise each pass would measure its own padding.
    final belowLastHeader = position.maxScrollExtent +
        position.viewportDimension -
        _tail -
        (lastTop + position.pixels);
    final tail = (position.viewportDimension - belowLastHeader)
        .clamp(_minTail, position.viewportDimension);
    if ((tail - _tail).abs() > 1) setState(() => _tail = tail);
  }

  void _syncActiveCategory() {
    if (_sections.isEmpty || !_scroll.hasClients) return;
    final position = _scroll.position;

    String active = _sections.first.id;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 1) {
      // At the very bottom the last header may never reach the top of the
      // list, so scrolling to the end would otherwise never select the last
      // tab. Reading the end of the menu means being on the last category.
      active = _sections.last.id;
    } else {
      for (var i = 0; i < _sections.length; i++) {
        final top = _headerTop(_sections[i].id);
        if (top == null) continue; // not built — keep looking.
        if (top <= _headerSnap) {
          active = _sections[i].id;
        } else {
          // The first header still below the line: the section above it is
          // the one filling the screen.
          if (i > 0) active = _sections[i - 1].id;
          break;
        }
      }
    }

    if (active != _categoryId) {
      setState(() => _categoryId = active);
      _revealChip(active);
    }
  }

  /// Keep the highlighted chip inside the strip as the list moves through
  /// categories that started off screen.
  void _revealChip(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[id]?.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _onCategoryTap(String id) async {
    setState(() => _categoryId = id);
    _revealChip(id);
    await _scrollToSection(id);
  }

  /// Every heading is a sliver of its own, so the list has laid all of them
  /// out even when they are far off screen — a tab can jump straight to its
  /// section instead of walking there.
  ///
  /// Where a section that has not been reached yet *starts* is only an
  /// estimate, though: a list that builds its rows on demand can only guess
  /// the height of the ones it has never drawn. So aim, look at where the
  /// heading actually landed now that the rows around it are real, and aim
  /// again until it sits at the top.
  Future<void> _scrollToSection(String id) async {
    if (!_scroll.hasClients) return;
    _scrollingToSection = true;
    _scrollTarget = id;
    for (var attempt = 0; attempt < 6; attempt++) {
      final ctx = _headerKeys[id]?.currentContext;
      if (ctx == null || !ctx.mounted) break;
      await Scrollable.ensureVisible(
        ctx,
        duration: Duration(milliseconds: attempt == 0 ? 280 : 120),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || !_scroll.hasClients || _scrollTarget != id) return;
      final top = _headerTop(id);
      if (top == null || top.abs() <= 1) break;
      // Already as far down as the list goes.
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent) break;
    }
    if (_scrollTarget != id) return;
    _scrollTarget = null;
    _scrollingToSection = false;
    if (mounted) _syncActiveCategory();
  }

  List<_MenuSection> _buildSections(AppStore store) {
    final sections = <_MenuSection>[];
    for (final category in store.customerCategories) {
      final items = store.itemsInCategory(category.id);
      if (items.isEmpty) continue; // an empty tab is nothing to scroll to.
      sections.add(_MenuSection(
        id: category.id,
        title: store.categoryDisplayName(category.id),
        items: items,
      ));
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final table = store.activeTable;

    _sections = _buildSections(store);
    // The menu can change under the reader — a dish sells out, the language
    // flips — so remeasure once this frame is on screen.
    _queueSync();
    if (!_sections.any((s) => s.id == _categoryId)) {
      _categoryId = _sections.isEmpty ? kPopularCategoryId : _sections.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        automaticallyImplyLeading: false,
        title: store.restaurantDisplayName,
        subtitle: store.orderType == OrderType.takeaway
            ? t.takeaway
            : (table == null ? null : t.table(table.number)),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(11),
              ),
              child:
                  Text(store.settings.logo, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: t.changeTable,
            onPressed: () async {
              final confirmed = await confirmDialog(
                context,
                title: t.leaveTableTitle,
                message: t.leaveTableBody,
                confirmLabel: t.leaveTable,
                cancelLabel: t.cancel,
              );
              if (!context.mounted) return;
              if (confirmed) {
                store.leaveTable();
                widget.onLeaveTable();
              }
            },
            icon: const Icon(Icons.table_restaurant_rounded),
          ),
          _CartButton(count: store.cartItemCount, onPressed: widget.onOpenCart),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58 + 46),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Offered here rather than only in the cart, so someone who
                // has just scanned can choose to take it away straight away.
                _OrderTypeStrip(store: store),
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    controller: _chipScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    itemCount: _sections.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      return _CategoryChip(
                        key: _chipKey(section.id),
                        label: section.title,
                        selected: section.id == _categoryId,
                        onTap: () => _onCategoryTap(section.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // One continuous menu: every category in order, with the tab strip
      // following whatever is under the reader's thumb.
      body: _sections.isEmpty
          ? EmptyState(
              icon: Icons.ramen_dining_rounded,
              title: t.emptyCategory,
              message: t.emptyCategoryBody,
            )
          : PageWidth(
              maxWidth: 640,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) _queueSync();
                  return false;
                },
                child: CustomScrollView(
                  key: _listKey,
                  controller: _scroll,
                  slivers: [
                    for (var i = 0; i < _sections.length; i++) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          key: _headerKey(_sections[i].id),
                          padding: EdgeInsets.fromLTRB(16, i == 0 ? 16 : 24, 16, 10),
                          child: Text(
                            _sections[i].title,
                            style: AppType.screenTitle,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.separated(
                          itemCount: _sections[i].items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _FoodCard(
                            item: _sections[i].items[index],
                            store: store,
                          ),
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(child: SizedBox(height: _tail)),
                  ],
                ),
              ),
            ),
      // The running total sits above the tab bar so it is always in reach.
      bottomNavigationBar: CartSummaryBar(onTap: widget.onOpenCart),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: context.watch<AppStore>().text.cart,
          onPressed: onPressed,
          icon: const Icon(Icons.shopping_bag_rounded),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.card, width: 1.5),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: -0.1,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// Star badge for a house special.
class SignatureBadge extends StatelessWidget {
  const SignatureBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppStore>().text;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: tint(AppColors.statusCooking),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              size: 14, color: AppColors.statusCooking),
          const SizedBox(width: 3),
          Text(
            t.signature,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.statusCooking,
            ),
          ),
        ],
      ),
    );
  }

  final bool compact;
}

/// Strike-through original price beside the discounted one.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.item,
    required this.store,
    this.size = 16.5,
  });

  final MenuItem item;
  final AppStore store;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dim = !item.available;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          store.money(item.effectivePrice),
          style: AppType.price.copyWith(
            fontSize: size,
            color: dim
                ? AppColors.inkFaint
                : (item.hasDiscount ? AppColors.danger : AppColors.ink),
          ),
        ),
        if (item.hasDiscount) ...[
          const SizedBox(width: 7),
          Text(
            store.money(item.price),
            style: TextStyle(
              fontSize: size - 3,
              fontWeight: FontWeight.w600,
              color: AppColors.inkFaint,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item, required this.store});

  final MenuItem item;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final lang = store.language;
    final soldOut = !item.available;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: soldOut ? null : () => showFoodDetailSheet(context, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Opacity(
                    opacity: soldOut ? 0.4 : 1,
                    child: FoodImage.forItem(item),
                  ),
                ),
              ),
              if (item.hasDiscount && !soldOut)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(9),
                      ),
                    ),
                    child: Text(
                      t.off(item.discountPercent),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (soldOut)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        t.soldOut,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.signature)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: SignatureBadge(compact: true),
                  ),
                Text(
                  item.displayName(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(
                    color: soldOut ? AppColors.inkFaint : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.displayDescription(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: PriceRow(item: item, store: store)),
                    if (soldOut)
                      Text(
                        t.unavailable,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkFaint,
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: () => store.addToCart(item),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'KantumruyPro',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        child: Text(t.add),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dine in or take away, right under the restaurant name. A diner who scanned
/// a table starts on Dine in; anyone can flip to Takeaway in one tap, and back
/// again by naming a table.
class _OrderTypeStrip extends StatelessWidget {
  const _OrderTypeStrip({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                icon: Icons.restaurant_rounded,
                label: store.activeTable == null
                    ? t.dineIn
                    : '${t.dineIn} · ${store.activeTable!.number}',
                selected: store.orderType == OrderType.dineIn,
                onTap: () => switchToDineIn(context, store),
              ),
            ),
            Expanded(
              child: _Segment(
                icon: Icons.shopping_bag_rounded,
                label: t.takeaway,
                selected: store.orderType == OrderType.takeaway,
                onTap: () => store.setOrderType(OrderType.takeaway),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
