import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Sticky summary of the cart, pinned to the bottom of the menu.
///
/// It is the customer's running total: it slides up the moment the first dish
/// is added, pops each time the count changes so a second tap is never silent,
/// and opens the full order when tapped.
class CartSummaryBar extends StatefulWidget {
  const CartSummaryBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<CartSummaryBar> createState() => _CartSummaryBarState();
}

class _CartSummaryBarState extends State<CartSummaryBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  int _lastCount = 0;

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final count = store.cartItemCount;

    if (count != _lastCount) {
      final grew = count > _lastCount && _lastCount > 0;
      _lastCount = count;
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pop.forward(from: 0);
        });
      }
    }

    if (count == 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      key: const ValueKey('cart-summary-bar'),
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, slide, child) => Transform.translate(
        offset: Offset(0, slide * 90),
        child: child,
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.05, end: 1).animate(
          CurvedAnimation(parent: _pop, curve: Curves.easeOut),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: PageWidth(
            maxWidth: 640,
            child: Material(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadius.card),
              elevation: 6,
              shadowColor: const Color(0x33F15A24),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.itemsCount(count),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFE2D6),
                                height: 1.2,
                              ),
                            ),
                            Text(
                              store.money(store.cartTotal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          t.viewOrder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
