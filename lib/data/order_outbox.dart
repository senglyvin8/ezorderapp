import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_line.dart';
import '../models/order.dart';

/// Raised when an order could not be sent and is waiting on the device.
///
/// Not a failure from the customer's side: their order was taken, it is safe,
/// and it goes to the kitchen when the connection returns. It is a distinct
/// type so the screen can say that rather than showing the network error it
/// would otherwise report as a refusal.
///
/// A [StateError] like the rest, so a caller that has not been taught about it
/// still shows the message instead of crashing.
class OrderHeldOffline extends StateError {
  OrderHeldOffline(super.message);
}

/// An order that was taken but has not reached the restaurant yet.
///
/// Everything needed to send it again later, and nothing that the server
/// decides: no order number, no total, no status. Those are the database's to
/// assign, and inventing them here would mean showing a diner a number that
/// changes under them.
class PendingOrder {
  const PendingOrder({
    required this.key,
    required this.type,
    required this.lines,
    required this.takenAt,
    this.tableId,
    this.note = '',
    this.onBehalfOfCustomer = false,
    this.attempts = 0,
    this.lastError,
  });

  /// Minted on this device before the first attempt, and kept across every
  /// retry.
  ///
  /// This is what makes retrying safe. If the network dies after Postgres has
  /// committed but before the reply arrives, the app cannot tell success from
  /// failure — and sending again without a key would charge the table twice.
  /// The database recognises the key and hands back the order it already has.
  final String key;

  final OrderType type;
  final String? tableId;
  final List<CartLine> lines;
  final String note;

  /// True when a member of staff keyed this in at the counter.
  final bool onBehalfOfCustomer;

  /// When the customer actually ordered — not when it was sent. A ticket that
  /// waited twenty minutes for the wifi should say so.
  final DateTime takenAt;

  final int attempts;
  final String? lastError;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  double get total => lines.fold(0, (sum, l) => sum + l.lineTotal);

  PendingOrder copyWith({int? attempts, String? lastError}) => PendingOrder(
        key: key,
        type: type,
        tableId: tableId,
        lines: lines,
        note: note,
        onBehalfOfCustomer: onBehalfOfCustomer,
        takenAt: takenAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type.wire,
        if (tableId != null) 'tableId': tableId,
        'lines': lines.map((l) => l.toJson()).toList(),
        'note': note,
        'onBehalfOfCustomer': onBehalfOfCustomer,
        'takenAt': takenAt.toIso8601String(),
        'attempts': attempts,
        if (lastError != null) 'lastError': lastError,
      };

  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
        key: json['key'] as String,
        type: OrderType.fromWire(json['type'] as String? ?? 'DINE_IN'),
        tableId: json['tableId'] as String?,
        lines: (json['lines'] as List<dynamic>)
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String? ?? '',
        onBehalfOfCustomer: json['onBehalfOfCustomer'] as bool? ?? false,
        takenAt: DateTime.parse(json['takenAt'] as String),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['lastError'] as String?,
      );
}

/// Orders taken while the restaurant was unreachable, waiting to be sent.
///
/// A restaurant's wifi drops. It drops during service, when the room is full,
/// and the alternative to holding the order is telling somebody who has
/// already chosen their food to start again. So the order is written to the
/// device first and sent when the connection comes back.
///
/// Deliberately only orders. A dish that sold out, a payment that was refused,
/// a plan cap — those are the database saying no, and no amount of retrying
/// changes the answer. Only a failure that never reached it belongs here.
class OrderOutbox {
  OrderOutbox({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _prefsKey = 'rqo_outbox_v1';

  SharedPreferences? _prefs;
  List<PendingOrder> _queue = [];

  /// Oldest first — the order they were taken in, which is the order the
  /// kitchen should receive them in.
  List<PendingOrder> get pending => List.unmodifiable(_queue);

  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_prefsKey);
    if (raw == null) return;
    try {
      _queue = (jsonDecode(raw) as List<dynamic>)
          .map((e) => PendingOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // A queue that will not parse cannot be sent, and refusing to open the
      // app over it would be worse than losing it. This is the one place that
      // drops an order, and it should be impossible.
      _queue = [];
      await _save();
    }
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _prefsKey,
      jsonEncode(_queue.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(PendingOrder order) async {
    // Guard against the same order being queued twice — a double tap on
    // Submit while the network is already failing.
    if (_queue.any((e) => e.key == order.key)) return;
    _queue = [..._queue, order];
    await _save();
  }

  Future<void> remove(String key) async {
    _queue = _queue.where((e) => e.key != key).toList();
    await _save();
  }

  /// Records that an attempt failed, so the reason can be shown rather than
  /// leaving somebody guessing why an order is still sitting there.
  Future<void> recordFailure(String key, String error) async {
    _queue = _queue
        .map((e) => e.key == key
            ? e.copyWith(attempts: e.attempts + 1, lastError: error)
            : e)
        .toList();
    await _save();
  }

  Future<void> clear() async {
    _queue = [];
    await _save();
  }
}
