import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/demo_data.dart';
import '../../models/menu_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/bilingual_field.dart';
import '../../widgets/food_image.dart';
import '../../widgets/photo_picker.dart';
import 'category_dialog.dart';

/// Add or edit a dish. Passing null for [item] creates a new one.
Future<void> showMenuItemEditor(
  BuildContext context, {
  MenuItem? item,
  String? categoryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MenuItemEditor(item: item, categoryId: categoryId),
  );
}

class _MenuItemEditor extends StatefulWidget {
  const _MenuItemEditor({this.item, this.categoryId});

  final MenuItem? item;
  final String? categoryId;

  @override
  State<_MenuItemEditor> createState() => _MenuItemEditorState();
}

class _MenuItemEditorState extends State<_MenuItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.item?.name ?? '');
  late final TextEditingController _nameKm =
      TextEditingController(text: widget.item?.nameKm ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.item?.description ?? '');
  late final TextEditingController _descriptionKm =
      TextEditingController(text: widget.item?.descriptionKm ?? '');
  late final TextEditingController _price = TextEditingController(
    text: widget.item == null ? '' : widget.item!.price.toStringAsFixed(2),
  );
  late final TextEditingController _discount = TextEditingController(
    text: (widget.item?.discountPercent ?? 0) == 0
        ? ''
        : '${widget.item!.discountPercent}',
  );

  late String _categoryId;
  late String _image = widget.item?.image ?? 'placeholder';
  late String? _photo = widget.item?.photo;
  late bool _available = widget.item?.available ?? true;
  late bool _popular = widget.item?.popular ?? false;
  late bool _signature = widget.item?.signature ?? false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _categoryId = widget.item?.categoryId ??
        widget.categoryId ??
        (store.sortedCategories.isNotEmpty
            ? store.sortedCategories.first.id
            : '');
    _price.addListener(_refresh);
    _discount.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _nameKm.dispose();
    _description.dispose();
    _descriptionKm.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  int get _discountValue {
    final parsed = int.tryParse(_discount.text.trim()) ?? 0;
    return parsed.clamp(0, 90).toInt();
  }

  double get _priceValue => double.tryParse(_price.text.trim()) ?? 0;

  double get _effectivePrice => _discountValue <= 0
      ? _priceValue
      : double.parse(
          (_priceValue * (100 - _discountValue) / 100).toStringAsFixed(2));

  Future<void> _newCategory(AppStore store) async {
    final created = await showCategoryDialog(context, store);
    if (created != null && mounted) {
      setState(() => _categoryId = created);
    }
  }

  void _save(AppStore store) {
    final t = store.text;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId.isEmpty) {
      showToast(context, t.createCategoryFirst, error: true);
      return;
    }

    if (widget.item == null) {
      store.addMenuItem(
        name: _name.text.trim(),
        nameKm: _nameKm.text.trim(),
        description: _description.text.trim(),
        descriptionKm: _descriptionKm.text.trim(),
        price: _priceValue,
        categoryId: _categoryId,
        image: _image,
        photo: _photo,
        discountPercent: _discountValue,
        available: _available,
        popular: _popular,
        signature: _signature,
      );
    } else {
      store.updateMenuItem(
        widget.item!.copyWith(
          name: _name.text.trim(),
          nameKm: _nameKm.text.trim(),
          description: _description.text.trim(),
          descriptionKm: _descriptionKm.text.trim(),
          price: _priceValue,
          categoryId: _categoryId,
          image: _image,
          photo: _photo,
          clearPhoto: _photo == null,
          discountPercent: _discountValue,
          available: _available,
          popular: _popular,
          signature: _signature,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final categories = store.sortedCategories;
    final isNew = widget.item == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isNew ? t.addDish : t.editDish,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: t.close,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: PageWidth(
                    maxWidth: 560,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BilingualField(
                            t: t,
                            label: t.dishName,
                            english: _name,
                            khmer: _nameKm,
                            textCapitalization: TextCapitalization.words,
                            englishValidator: (value) =>
                                (value ?? '').trim().isEmpty
                                    ? t.enterDishName
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          BilingualField(
                            t: t,
                            label: t.description,
                            english: _description,
                            khmer: _descriptionKm,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.khmerFallbackHint,
                            style: const TextStyle(
                                fontSize: 13.5, color: AppColors.inkFaint),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _price,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: appInput(
                                    label: t.price,
                                    prefixText:
                                        '${store.settings.currencySymbol} ',
                                  ),
                                  validator: (value) {
                                    final parsed =
                                        double.tryParse((value ?? '').trim());
                                    if (parsed == null || parsed <= 0) {
                                      return t.enterPrice;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _discount,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: appInput(
                                    label: t.discountPercent,
                                    hint: '0',
                                  ),
                                  validator: (value) {
                                    final raw = (value ?? '').trim();
                                    if (raw.isEmpty) return null;
                                    final parsed = int.tryParse(raw);
                                    if (parsed == null ||
                                        parsed < 0 ||
                                        parsed > 90) {
                                      return '0 – 90';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _DiscountPreview(
                            hasDiscount: _discountValue > 0 && _priceValue > 0,
                            full: store.money(_priceValue),
                            effective: store.money(_effectivePrice),
                            percent: _discountValue,
                            store: store,
                          ),
                          const SizedBox(height: 20),
                          SectionLabel(
                            t.category,
                            trailing: TextButton.icon(
                              onPressed: () => _newCategory(store),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(t.addCategory),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final category in categories)
                                _ChoicePill(
                                  label: category.displayName(store.language),
                                  selected: category.id == _categoryId,
                                  onTap: () => setState(
                                      () => _categoryId = category.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SectionLabel(t.image),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: FoodImage(_image, photo: _photo),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: PhotoSourceButtons(
                                  t: t,
                                  hasPhoto: _photo != null,
                                  onPicked: (base64) =>
                                      setState(() => _photo = base64),
                                  onRemoved: () =>
                                      setState(() => _photo = null),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.orPickIllustration,
                            style: const TextStyle(
                                fontSize: 13.5, color: AppColors.inkFaint),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 78,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: DemoData.imageChoices.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final key = DemoData.imageChoices[index];
                                final selected = key == _image && _photo == null;
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _image = key;
                                    _photo = null;
                                  }),
                                  child: Container(
                                    width: 78,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.brand
                                            : AppColors.border,
                                        width: selected ? 2.4 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: FoodImage(key),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 22),
                          _ToggleRow(
                            title: t.availableToggle,
                            subtitle:
                                _available ? t.availableOn : t.availableOff,
                            value: _available,
                            onChanged: (value) =>
                                setState(() => _available = value),
                          ),
                          const Divider(height: 24),
                          _ToggleRow(
                            title: t.showInPopular,
                            subtitle: t.showInPopularBody,
                            value: _popular,
                            onChanged: (value) =>
                                setState(() => _popular = value),
                          ),
                          const Divider(height: 24),
                          _ToggleRow(
                            title: t.signatureDish,
                            subtitle: t.signatureDishBody,
                            value: _signature,
                            leading: const Icon(Icons.star_rounded,
                                size: 20, color: AppColors.statusCooking),
                            onChanged: (value) =>
                                setState(() => _signature = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: PageWidth(
                  maxWidth: 560,
                  child: Row(
                    children: [
                      if (!isNew) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final confirmed = await confirmDialog(
                                context,
                                title: t.deleteDishTitle(widget.item!.name),
                                message: t.deleteDishBody,
                                confirmLabel: t.delete,
                                cancelLabel: t.cancel,
                                destructive: true,
                              );
                              if (!context.mounted) return;
                              if (confirmed) {
                                store.deleteMenuItem(widget.item!.id);
                                Navigator.of(context).pop();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: Text(t.delete),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => _save(store),
                          child: Text(isNew ? t.addDish : t.saveChanges),
                        ),
                      ),
                    ],
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

class _DiscountPreview extends StatelessWidget {
  const _DiscountPreview({
    required this.hasDiscount,
    required this.full,
    required this.effective,
    required this.percent,
    required this.store,
  });

  final bool hasDiscount;
  final String full;
  final String effective;
  final int percent;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    if (!hasDiscount) {
      return Text(
        t.noDiscount,
        style: const TextStyle(fontSize: 14, color: AppColors.inkFaint),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint(AppColors.danger),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t.off(percent),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            full,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.inkSoft,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.customerPays(effective),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.inkSoft)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
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
      color: selected ? AppColors.brandTint : AppColors.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.brandDark : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
