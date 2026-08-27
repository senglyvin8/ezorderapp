import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan.dart';
import '../models/upgrade_request.dart';
import 'merchant.dart';
import 'upgrade_queue.dart';

/// State for the operator console.
///
/// Deliberately its own small thing rather than a mode of [AppStore]. The two
/// apps share a database and nothing else: this one has no cart, no table, no
/// language switch, no realtime, and it must not be able to reach a merchant's
/// tables. Folding it into the restaurant app would have meant the diner's
/// bundle carrying code that queries every restaurant on the platform.
class PlatformStore extends ChangeNotifier {
  PlatformStore(this._client);

  final SupabaseClient _client;

  List<Merchant> _merchants = [];
  List<UpgradeTicket> _requests = [];
  bool _loading = false;
  String? _error;

  List<Merchant> get merchants => List.unmodifiable(_merchants);

  /// The upgrade queue: merchants who have asked to be moved onto a bigger
  /// plan. Open ones first, oldest first within that.
  List<UpgradeTicket> get requests => List.unmodifiable(_requests);

  List<UpgradeTicket> get openRequests =>
      _requests.where((r) => r.isOpen).toList();

  int get openRequestCount => openRequests.length;

  /// The open request from one merchant, shown on their card. There can only
  /// be one — the partial unique index in 0010_upgrades.sql sees to that.
  UpgradeTicket? requestFor(String restaurantId) => _requests
      .where((r) => r.isOpen && r.restaurantId == restaurantId)
      .firstOrNull;
  bool get loading => _loading;
  String? get error => _error;

  bool get isSignedIn => _client.auth.currentUser != null;
  String get signedInAs => _client.auth.currentUser?.email ?? '';

  // ------------------------------------------------------------- platform sums

  int get merchantCount => _merchants.length;
  int get suspendedCount => _merchants.where((m) => m.suspended).length;
  int get atLimitCount => _merchants.where((m) => m.atAnyLimit).length;
  int get dormantCount => _merchants.where((m) => !m.hasEverOrdered).length;

  /// The number the console exists for: how many merchants want something
  /// from you today.
  int get needsAttentionCount =>
      _merchants.where((m) => m.needsAttention).length;

  int get notSetUpCount =>
      _merchants.where((m) => m.health == MerchantHealth.notSetUp).length;
  int get quietCount =>
      _merchants.where((m) => m.health == MerchantHealth.quiet).length;
  int get activeCount =>
      _merchants.where((m) => m.health == MerchantHealth.active).length;

  int countOf(MerchantHealth health) =>
      _merchants.where((m) => m.health == health).length;

  /// Filtered and searched, sorted so the ones needing something come first.
  ///
  /// Within that, by most recently active: a merchant who was busy yesterday
  /// and has stopped is more urgent than one who has been quiet for a month.
  List<Merchant> visible({
    MerchantHealth? health,
    bool onlyNeedingAttention = false,
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    final list = _merchants.where((m) {
      if (health != null && m.health != health) return false;
      if (onlyNeedingAttention && !m.needsAttention) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.slug.toLowerCase().contains(q) ||
          m.phone.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.needsAttention != b.needsAttention) {
          return a.needsAttention ? -1 : 1;
        }
        final aWhen = a.lastOrderAt ?? a.createdAt;
        final bWhen = b.lastOrderAt ?? b.createdAt;
        return bWhen.compareTo(aWhen);
      });
    return list;
  }

  double get revenueToday =>
      _merchants.fold(0, (sum, m) => sum + m.revenueToday);
  int get ordersToday => _merchants.fold(0, (sum, m) => sum + m.ordersToday);

  /// Monthly recurring revenue, as billed rather than as collected — there is
  /// no billing yet, so this is what the current plans would bring in.
  double get monthlyRecurring => _merchants
      .where((m) => !m.suspended)
      .fold(0, (sum, m) => sum + m.plan.monthlyPrice);

  Map<Plan, int> get byPlan {
    final counts = {for (final p in Plan.values) p: 0};
    for (final m in _merchants) {
      counts[m.plan] = (counts[m.plan] ?? 0) + 1;
    }
    return counts;
  }

  // ------------------------------------------------------------------- auth

  /// Real email and password: platform admins are your own people, not
  /// restaurant staff tapping a name on a pad.
  ///
  /// Returns null on success, or a message to show. Being on the list is
  /// checked by asking the database, not by trusting that a sign-in succeeded
  /// — anyone with an account on this project can sign in here, and only
  /// membership of `platform_admins` should get them any further.
  Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
    } on AuthException {
      return 'Wrong email or password';
    }
    final allowed = await _client.rpc<bool>('is_platform_admin');
    if (allowed != true) {
      await _client.auth.signOut();
      return 'That account is not a platform administrator';
    }
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _merchants = [];
    notifyListeners();
  }

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _client.rpc<List<dynamic>>('platform_overview');
      _merchants = rows
          .map((r) => Merchant.fromRow(r as Map<String, dynamic>))
          .toList();
      _requests = await _loadRequests();
    } catch (error) {
      _error = _clean(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// A project that has not run 0010 yet has no queue, and the console has to
  /// keep working for everything else it does. An empty queue is the honest
  /// answer there — not a screen that will not open.
  Future<List<UpgradeTicket>> _loadRequests() async {
    try {
      final rows =
          await _client.rpc<List<dynamic>>('platform_upgrade_requests');
      return rows
          .map((r) => UpgradeTicket.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // -------------------------------------------------------------- mutations

  Future<void> setPlan(Merchant merchant, Plan plan) => _run(() =>
      _client.rpc<void>('platform_set_plan', params: {
        'p_restaurant_id': merchant.id,
        'p_plan': plan.wire,
      }));

  /// Moving a merchant onto a plan closes their open request as well — a
  /// trigger does it, in `0010_upgrades.sql`, so it happens whether the change
  /// came from here or from the SQL editor.
  Future<void> resolveRequest(
    UpgradeTicket request,
    UpgradeStatus status, {
    String note = '',
  }) =>
      _run(() =>
          _client.rpc<void>('platform_resolve_upgrade_request', params: {
            'p_id': request.id,
            'p_status': status.wire,
            'p_note': note,
          }));

  Future<void> setSuspended(Merchant merchant, bool suspended) => _run(() =>
      _client.rpc<void>('platform_set_suspended', params: {
        'p_restaurant_id': merchant.id,
        'p_suspended': suspended,
      }));

  Future<void> createMerchant({
    required String slug,
    required String name,
    required String adminUsername,
    required String adminPassword,
  }) =>
      _run(() => _client.rpc<String>('platform_create_merchant', params: {
            'p_slug': slug.trim().toLowerCase(),
            'p_name': name.trim(),
            'p_admin_username': adminUsername.trim().toLowerCase(),
            'p_admin_password': adminPassword,
          }));

  /// Every mutation reloads. The list is small, the changes are rare, and a
  /// console that shows a stale plan after you have just changed it is worse
  /// than one that takes an extra moment.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on PostgrestException catch (e) {
      throw StateError(_cleanMessage(e.message));
    }
    await load();
  }

  static String _clean(Object error) => switch (error) {
        PostgrestException e => _cleanMessage(e.message),
        AuthException e => _cleanMessage(e.message),
        _ => 'Could not reach the platform. $error',
      };

  static String _cleanMessage(String message) {
    final trimmed = message.trim();
    for (final prefix in const ['ERROR:', 'error:']) {
      if (trimmed.startsWith(prefix)) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return trimmed;
  }
}
