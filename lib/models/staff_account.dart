import '../auth/credentials.dart';

/// What a signed-in person is allowed to do.
///
/// Admin is a superset: it can work the kitchen and the till as well as manage
/// the restaurant, because in a small shop the owner does all three.
enum StaffRole {
  admin('ADMIN'),
  kitchen('KITCHEN'),
  cashier('CASHIER');

  const StaffRole(this.wire);
  final String wire;

  static StaffRole fromWire(String value) => StaffRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => StaffRole.kitchen,
      );

  bool get canManageRestaurant => this == StaffRole.admin;
  bool get canWorkKitchen => this == StaffRole.admin || this == StaffRole.kitchen;
  bool get canTakePayment => this == StaffRole.admin || this == StaffRole.cashier;
}

/// A staff member. Admins sign in with a username and password; kitchen and
/// cashier staff tap their name and enter a six digit PIN.
class StaffAccount {
  /// Every staff PIN is exactly this long, so the pad can submit on the last
  /// digit instead of asking for a confirm tap.
  static const int pinLength = 6;

  const StaffAccount({
    required this.id,
    required this.name,
    required this.role,
    this.salt = '',
    this.secretHash = '',
    this.username = '',
    this.active = true,
  });

  final String id;
  final String name;
  final StaffRole role;

  /// Only admins have one; staff are picked from a list instead.
  final String username;

  /// Empty when the account lives behind Supabase Auth: the secret is the
  /// server's to hold, and this device never sees it. Only the on-device demo
  /// backend fills these in.
  final String salt;
  final String secretHash;

  bool get hasLocalSecret => salt.isNotEmpty && secretHash.isNotEmpty;
  final bool active;

  bool get usesPassword => role == StaffRole.admin;

  /// Only meaningful on the demo backend. A Supabase-backed account has no
  /// secret here to check against, so this is always false — the answer comes
  /// from the server instead.
  bool verify(String secret) =>
      active && hasLocalSecret && Credentials.verify(secret, salt, secretHash);

  StaffAccount copyWith({
    String? name,
    StaffRole? role,
    String? username,
    String? salt,
    String? secretHash,
    bool? active,
  }) =>
      StaffAccount(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        username: username ?? this.username,
        salt: salt ?? this.salt,
        secretHash: secretHash ?? this.secretHash,
        active: active ?? this.active,
      );

  /// Replaces the stored secret with a freshly salted hash of [secret].
  StaffAccount withSecret(String secret) {
    final salt = Credentials.newSalt();
    return copyWith(salt: salt, secretHash: Credentials.hash(secret, salt));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.wire,
        if (username.isNotEmpty) 'username': username,
        if (salt.isNotEmpty) 'salt': salt,
        if (secretHash.isNotEmpty) 'secretHash': secretHash,
        'active': active,
      };

  factory StaffAccount.fromJson(Map<String, dynamic> json) => StaffAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        role: StaffRole.fromWire(json['role'] as String),
        username: json['username'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        secretHash: json['secretHash'] as String? ?? '',
        active: json['active'] as bool? ?? true,
      );

  /// Builds an account from a plain secret, used when seeding and when the
  /// admin creates someone.
  factory StaffAccount.create({
    required String id,
    required String name,
    required StaffRole role,
    required String secret,
    String username = '',
  }) {
    final salt = Credentials.newSalt();
    return StaffAccount(
      id: id,
      name: name,
      role: role,
      username: username,
      salt: salt,
      secretHash: Credentials.hash(secret, salt),
    );
  }
}
