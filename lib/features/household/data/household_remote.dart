import '../../sync/data/postgrest_client.dart';
import '../domain/household.dart';

/// The household actions that need the server.
abstract class HouseholdRemote {
  /// The household the signed-in person is in, or null.
  Future<HouseholdInfo?> fetch();

  Future<String> create(String name, String? displayName);

  /// A new invite code (owner only).
  Future<String> createInvite();

  Future<void> join(String code, String? displayName);

  Future<LeaveResult> leave();

  Future<void> removeMember(String userId);

  Future<void> rename(String name);
}

/// Talks to the functions in supabase/migrations/0002_households.sql.
class PostgrestHouseholdRemote implements HouseholdRemote {
  PostgrestHouseholdRemote(this._client);

  final PostgrestClient _client;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on RemoteFailure catch (e) {
      throw _translate(e);
    }
  }

  static HouseholdException _translate(RemoteFailure e) {
    if (e.offline) return HouseholdException(HouseholdProblem.offline);
    final text = e.message.toLowerCase();
    if (text.contains('invalid or expired code')) {
      return HouseholdException(HouseholdProblem.badCode, e.message);
    }
    if (text.contains('already in a household')) {
      return HouseholdException(HouseholdProblem.alreadyMember, e.message);
    }
    if (text.contains('only the owner')) {
      return HouseholdException(HouseholdProblem.notOwner, e.message);
    }
    return HouseholdException(HouseholdProblem.other, e.message);
  }

  @override
  Future<HouseholdInfo?> fetch() => _run(() async {
    final households = await _client.select('households');
    if (households.isEmpty) return null;
    final h = households.first;
    final members = await _client.select(
      'household_members',
      query: {
        'select': '*',
        'household_id': 'eq.${h['id']}',
        'order': 'joined_at.asc',
      },
    );
    return HouseholdInfo(
      id: h['id'] as String,
      name: h['name'] as String,
      ownerId: h['owner_id'] as String,
      members: [for (final m in members) HouseholdMember.fromJson(m)],
    );
  });

  @override
  Future<String> create(String name, String? displayName) => _run(() async {
    final id = await _client.call('create_household', {
      'p_name': name,
      'p_display_name': displayName,
    });
    return id as String;
  });

  @override
  Future<String> createInvite() => _run(() async {
    final code = await _client.call('create_invite');
    return code as String;
  });

  @override
  Future<void> join(String code, String? displayName) => _run(() async {
    await _client.call('join_household', {
      'p_code': code,
      'p_display_name': displayName,
    });
  });

  @override
  Future<LeaveResult> leave() => _run(() async {
    final result = await _client.call('leave_household');
    return result == 'dissolved' ? LeaveResult.dissolved : LeaveResult.left;
  });

  @override
  Future<void> removeMember(String userId) => _run(() async {
    await _client.call('remove_member', {'p_user': userId});
  });

  @override
  Future<void> rename(String name) => _run(() async {
    await _client.call('rename_household', {'p_name': name});
  });
}
