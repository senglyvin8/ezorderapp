import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/staff_account.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../auth/sign_in_screen.dart';

/// Admin-only: who can sign in, and what they are allowed to touch.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;
    final accounts = store.accounts;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appTopBar(
        title: t.staff,
        subtitle: t.staffCount(accounts.length),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'staff-fab',
        onPressed: () => showStaffEditor(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: Text(t.addStaff),
      ),
      body: PageWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SectionLabel(t.staffSubtitle),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const Divider(),
                    _StaffRow(account: accounts[i], store: store),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.account, required this.store});

  final StaffAccount account;
  final AppStore store;

  Future<void> _act(BuildContext context, String action) async {
    final t = store.text;
    try {
      switch (action) {
        case 'edit':
          await showStaffEditor(context, account: account);
        case 'toggle':
          store.setStaffActive(account.id, !account.active);
        case 'delete':
          final confirmed = await confirmDialog(
            context,
            title: t.deleteDishTitle(account.name),
            message: t.staffSubtitle,
            confirmLabel: t.delete,
            cancelLabel: t.cancel,
            destructive: true,
          );
          if (!context.mounted || !confirmed) return;
          store.deleteStaff(account.id);
      }
    } on StateError catch (error) {
      if (context.mounted) showToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = store.text;
    final isMe = store.currentUser?.id == account.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint(roleColor(account.role)),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(roleIcon(account.role),
                size: 20, color: roleColor(account.role)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.person_pin_circle_rounded,
                          size: 15, color: AppColors.inkFaint),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  account.usesPassword
                      ? '${roleLabel(account.role, t)}  ·  ${account.username}'
                      : roleLabel(account.role, t),
                  style: AppType.label,
                ),
              ],
            ),
          ),
          if (!account.active)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tint(AppColors.danger),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t.inactive,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
            onSelected: (value) => _act(context, value),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(t.editStaff)),
              PopupMenuItem(
                value: 'toggle',
                child: Text(account.active ? t.turnOff : t.turnOn),
              ),
              PopupMenuItem(value: 'delete', child: Text(t.delete)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create or edit an account. The secret is only ever set, never shown.
Future<void> showStaffEditor(
  BuildContext context, {
  StaffAccount? account,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _StaffEditor(account: account),
  );
}

class _StaffEditor extends StatefulWidget {
  const _StaffEditor({this.account});

  final StaffAccount? account;

  @override
  State<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends State<_StaffEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _secret;
  late StaffRole _role;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.account?.name ?? '');
    _username = TextEditingController(text: widget.account?.username ?? '');
    _secret = TextEditingController();
    _role = widget.account?.role ?? StaffRole.kitchen;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _isNew => widget.account == null;
  bool get _needsPassword => _role == StaffRole.admin;

  void _save(AppStore store) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      if (_isNew) {
        store.addStaff(
          name: _name.text,
          role: _role,
          secret: _secret.text,
          username: _needsPassword ? _username.text : '',
        );
      } else {
        store.renameStaff(widget.account!.id, _name.text.trim());
        if (_secret.text.trim().isNotEmpty) {
          store.resetStaffSecret(widget.account!.id, _secret.text.trim());
        }
      }
      Navigator.of(context).pop();
    } on StateError catch (error) {
      showToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.text;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: PageWidth(
              maxWidth: 480,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isNew ? t.addStaff : t.editStaff,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: appInput(label: t.staffName),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? t.staffName : null,
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(t.role),
                    for (final role in StaffRole.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RoleOption(
                          role: role,
                          label: roleLabel(role, t),
                          description: switch (role) {
                            StaffRole.admin => t.roleAdminDesc,
                            StaffRole.kitchen => t.roleKitchenDesc,
                            StaffRole.cashier => t.roleCashierDesc,
                          },
                          selected: _role == role,
                          // Changing an existing account's role would strip
                          // access from someone mid-shift; delete and recreate.
                          onTap: _isNew
                              ? () => setState(() => _role = role)
                              : null,
                        ),
                      ),
                    if (_needsPassword) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _username,
                        autocorrect: false,
                        enabled: _isNew,
                        decoration: appInput(label: t.username),
                        validator: (value) => _isNew &&
                                (value ?? '').trim().isEmpty
                            ? t.username
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _secret,
                      obscureText: true,
                      keyboardType:
                          _needsPassword ? null : TextInputType.number,
                      inputFormatters: _needsPassword
                          ? null
                          : [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                  StaffAccount.pinLength),
                            ],
                      decoration: appInput(
                        label: _isNew
                            ? (_needsPassword ? t.password : t.pin)
                            : (_needsPassword ? t.newPassword : t.newPin),
                        hint: _needsPassword ? t.passwordRule : t.pinRule,
                      ),
                      validator: (value) {
                        final raw = (value ?? '').trim();
                        if (!_isNew && raw.isEmpty) return null;
                        if (_needsPassword) {
                          return raw.length >= 8 ? null : t.passwordRule;
                        }
                        return raw.length == StaffAccount.pinLength
                            ? null
                            : t.pinRule;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => _save(store),
                      child: Text(_isNew ? t.addStaff : t.save),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final StaffRole role;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled || selected ? 1 : 0.45,
      child: Material(
        color: selected ? AppColors.brandTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(roleIcon(role), size: 19, color: roleColor(role)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text(description, style: AppType.label),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 19, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
