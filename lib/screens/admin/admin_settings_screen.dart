import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/app_text.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/merchant_id_card.dart';
import '../../widgets/sign_in_email_card.dart';

/// Restaurant profile, currency and the payment methods the cashier offers
/// (Rule 10).
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // Resolved in initState rather than as lazy fields, so nothing reaches for
  // an ancestor during dispose() if this tab was never opened.
  late final AppStore _store;
  late final TextEditingController _name;
  late final TextEditingController _nameKm;
  late final TextEditingController _logo;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _symbol;
  late final TextEditingController _code;
  late List<String> _methods;

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>();
    final settings = _store.settings;
    _name = TextEditingController(text: settings.name);
    _nameKm = TextEditingController(text: settings.nameKm);
    _logo = TextEditingController(text: settings.logo);
    _phone = TextEditingController(text: settings.phone);
    _address = TextEditingController(text: settings.address);
    _symbol = TextEditingController(text: settings.currencySymbol);
    _code = TextEditingController(text: settings.currencyCode);
    _methods = [...settings.paymentMethods];
  }

  @override
  void dispose() {
    _name.dispose();
    _nameKm.dispose();
    _logo.dispose();
    _phone.dispose();
    _address.dispose();
    _symbol.dispose();
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final t = _store.text;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, t.needName, error: true);
      return;
    }
    if (_methods.isEmpty) {
      showToast(context, t.needMethod, error: true);
      return;
    }
    _store.updateSettings(
      _store.settings.copyWith(
        name: name,
        nameKm: _nameKm.text.trim(),
        logo: _logo.text.trim().isEmpty ? '🍽️' : _logo.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        currencySymbol:
            _symbol.text.trim().isEmpty ? r'$' : _symbol.text.trim(),
        currencyCode: _code.text.trim().toUpperCase(),
        paymentMethods: [..._methods],
      ),
    );
    showToast(context, t.settingsSaved);
  }

  Future<void> _addMethod() async {
    final t = _store.text;
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(t.addPaymentMethod,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: appInput(hint: t.paymentMethodHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel,
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.add),
          ),
        ],
      ),
    );
    final value = controller.text.trim();
    controller.dispose();
    if (saved == true && value.isNotEmpty && !_methods.contains(value)) {
      setState(() => _methods = [..._methods, value]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.settings,
        subtitle: t.settingsSubtitle,
        actions: [
          TextButton(onPressed: _save, child: Text(t.save)),
          const SizedBox(width: 8),
        ],
      ),
      body: PageWidth(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SectionLabel(t.language),
            AppCard(
              child: Row(
                children: [
                  for (final option in AppLanguage.values) ...[
                    if (option != AppLanguage.values.first)
                      const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => store.setLanguage(option),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: store.language == option
                              ? AppColors.brandTint
                              : null,
                          foregroundColor: store.language == option
                              ? AppColors.brandDark
                              : AppColors.inkSoft,
                          side: BorderSide(
                            color: store.language == option
                                ? AppColors.brand
                                : AppColors.border,
                          ),
                        ),
                        child: Text(option.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionLabel(t.restaurant),
            AppCard(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: _logo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22),
                          decoration: appInput(label: t.logo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: appInput(label: t.restaurantName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameKm,
                    decoration: appInput(label: t.restaurantNameKm),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: appInput(label: t.phoneNumber),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _address,
                    maxLines: 2,
                    decoration: appInput(label: t.address),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SignInEmailCard(store: store),
            const SizedBox(height: 10),
            MerchantIdCard(store: store),
            const SizedBox(height: 24),
            SectionLabel(t.currency),
            AppCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _symbol,
                      textAlign: TextAlign.center,
                      decoration: appInput(label: t.symbol),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: appInput(label: t.code),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionLabel(
              t.paymentMethods,
              trailing: TextButton.icon(
                onPressed: _addMethod,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(t.add),
              ),
            ),
            AppCard(
              child: _methods.isEmpty
                  ? Text(
                      t.noMethods,
                      style: const TextStyle(color: AppColors.danger),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final method in _methods)
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  method,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () => setState(
                                    () => _methods = _methods
                                        .where((m) => m != method)
                                        .toList(),
                                  ),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 16, color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
              child: Text(t.saveSettings),
            ),
            const SizedBox(height: 32),
            SectionLabel(t.prototype),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.resetDemo,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.resetDemoBody,
                    style: const TextStyle(
                        fontSize: 14.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await confirmDialog(
                        context,
                        title: t.resetDemoTitle,
                        message: t.resetDemoConfirm,
                        confirmLabel: t.reset,
                        cancelLabel: t.cancel,
                        destructive: true,
                      );
                      if (!confirmed || !mounted) return;
                      await _store.resetDemoData();
                      if (!context.mounted) return;
                      setState(() {
                        _name.text = _store.settings.name;
                        _nameKm.text = _store.settings.nameKm;
                        _logo.text = _store.settings.logo;
                        _phone.text = _store.settings.phone;
                        _address.text = _store.settings.address;
                        _symbol.text = _store.settings.currencySymbol;
                        _code.text = _store.settings.currencyCode;
                        _methods = [..._store.settings.paymentMethods];
                      });
                      showToast(context, t.demoRestored);
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 19),
                    label: Text(t.resetDemo),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
