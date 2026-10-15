import 'dart:convert';

/// One person in a household.
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.role,
    this.displayName,
    this.joinedAt,
  });

  final String userId;

  /// 'owner' or 'member'
  final String role;
  final String? displayName;
  final DateTime? joinedAt;

  bool get isOwner => role == 'owner';

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'role': role,
    'display_name': displayName,
    'joined_at': joinedAt?.toIso8601String(),
  };

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      HouseholdMember(
        userId: json['user_id'] as String,
        role: (json['role'] as String?) ?? 'member',
        displayName: json['display_name'] as String?,
        joinedAt: json['joined_at'] == null
            ? null
            : DateTime.tryParse(json['joined_at'] as String),
      );
}

/// The household the signed-in person belongs to, with its members.
class HouseholdInfo {
  const HouseholdInfo({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
  });

  final String id;
  final String name;
  final String ownerId;
  final List<HouseholdMember> members;

  bool isOwner(String? userId) => userId != null && userId == ownerId;

  HouseholdMember? member(String? userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  /// Who to show for a member; null when it is not known.
  String? nameOf(String? userId) {
    final name = member(userId)?.displayName;
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  /// A household with only one person shows no "added by" labels.
  bool get hasOthers => members.length > 1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'owner_id': ownerId,
    'members': [for (final m in members) m.toJson()],
  };

  factory HouseholdInfo.fromJson(Map<String, dynamic> json) => HouseholdInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['owner_id'] as String,
    members: [
      for (final m in (json['members'] as List? ?? const []))
        HouseholdMember.fromJson(m as Map<String, dynamic>),
    ],
  );

  String encode() => jsonEncode(toJson());

  static HouseholdInfo? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return HouseholdInfo.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Why a household action failed, in terms the screen can explain.
enum HouseholdProblem {
  /// The code is wrong or has expired.
  badCode,

  /// The person is already in a household.
  alreadyMember,

  /// Only the owner may do this.
  notOwner,

  /// No internet.
  offline,

  /// Anything else.
  other,
}

class HouseholdException implements Exception {
  HouseholdException(this.problem, [this.message = '']);

  final HouseholdProblem problem;
  final String message;

  @override
  String toString() => 'HouseholdException($problem): $message';
}

/// What leaving did on the server.
enum LeaveResult {
  /// The household goes on without this person.
  left,

  /// This person was the last one: the household ended and everything in it
  /// is now theirs.
  dissolved,
}
