import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/menu_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/food_image.dart';
import '../../widgets/qty_stepper.dart';
import 'menu_screen.dart';

/// Opens the dish detail as a bottom sheet — quicker than a page push on a
/// phone, and it keeps the menu behind it.
Future<void> showFoodDetailSheet(BuildContext context, MenuItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FoodDetailSheet(item: item),
  );
}

class FoodDetailSheet extends StatefulWidget {
  const FoodDetailSheet({super.key, required this.item});

  final MenuItem item;

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  int _quantity = 1;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final lang = store.language;
    final item = widget.item;
    final lineTotal = item.effectivePrice * _quantity;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: PageWidth(
                    maxWidth: 560,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: FoodImage(item.image),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: t.close,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.signature)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: SignatureBadge(),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.displayName(lang),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  PriceRow(item: item, store: store, size: 20),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.displayDescription(lang),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Text(
                                    t.quantity,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  QtyStepper(
                                    quantity: _quantity,
                                    onChanged: (value) =>
                                        setState(() => _quantity = value),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                t.specialRequest,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _note,
                                maxLines: 2,
                                textInputAction: TextInputAction.done,
                                decoration:
                                    appInput(hint: t.specialRequestHint),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: PageWidth(
                  maxWidth: 560,
                  child: FilledButton(
                    onPressed: () {
                      store.addToCart(
                        item,
                        quantity: _quantity,
                        note: _note.text,
                      );
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: Text(
                      '${t.addToCart}  ·  ${store.money(lineTotal)}',
                    ),
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
