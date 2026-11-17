enum UserRole { admin, sales, corporate }

enum UserStatus { active, inactive, pending }

/// Lightweight ownership lookup; no full user records or credentials are fetched.
class SalesAssignment {
  const SalesAssignment({required this.corporateId, required this.userId, required this.name});
  final String corporateId, userId, name;
  factory SalesAssignment.fromJson(Map<String, dynamic> json) => SalesAssignment(
    corporateId: _string(json, 'corporateId'), userId: _string(json, 'userId'), name: _string(json, 'name'));
}

class UserCorporate {
  const UserCorporate({required this.id, required this.name, this.nameTh});
  final String id;
  final String name;
  final String? nameTh;

  factory UserCorporate.fromJson(Map<String, dynamic> json) => UserCorporate(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    nameTh: json['nameTh'] as String?,
  );
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    required this.role,
    required this.status,
    required this.corporates,
    this.corporateId,
    this.corporateName,
  });
  final String id;
  final String name;
  final String email;
  final String userType;
  final UserRole role;
  final UserStatus status;
  final String? corporateId;
  final String? corporateName;
  final List<UserCorporate> corporates;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final type = _string(json, 'userType');
    if (type != 'platform' && type != 'corporate') {
      throw const FormatException('Invalid user type');
    }
    return ManagedUser(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      email: _string(json, 'email'),
      userType: type,
      role: UserRole.values.byName(_string(json, 'role')),
      status: UserStatus.values.byName(_string(json, 'status')),
      corporateId: json['corporateId'] as String?,
      corporateName: json['corporateName'] as String?,
      corporates: List.unmodifiable(
        (json['corporates'] as List).map(
          (value) => UserCorporate.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }
}

/// Tokens are intentionally excluded from toString/logging.
class UserInvite {
  const UserInvite({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;

  factory UserInvite.fromJson(Map<String, dynamic> json) => UserInvite(
    token: _string(json, 'inviteToken'),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (json['inviteExpiresAt'] as int) * 1000,
      isUtc: true,
    ),
  );
}

class CreatedUser {
  const CreatedUser(this.user, this.invite);
  final ManagedUser user;
  final UserInvite invite;
}

/// API request model keeps create and update contracts separate.
class UserDraft {
  const UserDraft({
    this.userType = 'corporate',
    this.fullName = '',
    this.email = '',
    this.role = UserRole.admin,
    this.status = UserStatus.pending,
    this.corporateId,
    this.corporateIds = const [],
  });
  final String userType;
  final String fullName;
  final String email;
  final UserRole role;
  final UserStatus status;
  final String? corporateId;
  final List<String> corporateIds;

  factory UserDraft.fromUser(ManagedUser user) => UserDraft(
    userType: user.userType,
    fullName: user.name,
    email: user.email,
    role: user.role == UserRole.corporate ? UserRole.admin : user.role,
    status: user.status,
    corporateId: user.corporateId,
    corporateIds: user.role == UserRole.sales
        ? user.corporates.map((c) => c.id).toList()
        : const [],
  );

  UserDraft copyWith({
    String? userType,
    String? fullName,
    String? email,
    UserRole? role,
    UserStatus? status,
    String? corporateId,
    List<String>? corporateIds,
  }) => UserDraft(
    userType: userType ?? this.userType,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    role: role ?? this.role,
    status: status ?? this.status,
    corporateId: corporateId ?? this.corporateId,
    corporateIds: List.unmodifiable(corporateIds ?? this.corporateIds),
  );

  Map<String, dynamic> createBody() => {
    'userType': userType,
    'fullName': fullName.trim(),
    'email': email.trim(),
    ..._scope(),
  };

  Map<String, dynamic> updateBody() => {
    'fullName': fullName.trim(),
    'status': status.name,
    ..._scope(),
  };

  Map<String, dynamic> _scope() => userType == 'corporate'
      ? {'corporateId': corporateId}
      : {
          'role': role.name,
          if (role == UserRole.sales) 'corporateIds': corporateIds,
        };
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid user response: $key');
  }
  return value;
}
