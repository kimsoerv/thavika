import 'package:thavika/features/household/data/household_remote.dart';
import 'package:thavika/features/household/domain/household.dart';

const me = 'user-me';
const partner = 'user-partner';
const hid = 'household-1';

/// What the server would answer; each test sets what it needs.
class FakeRemote implements HouseholdRemote {
  HouseholdInfo? household;
  HouseholdException? failWith;
  LeaveResult leaveResult = LeaveResult.left;
  final calls = <String>[];
  String? lastDisplayName;

  void _check() {
    final problem = failWith;
    if (problem != null) throw problem;
  }

  @override
  Future<HouseholdInfo?> fetch() async {
    _check();
    return household;
  }

  @override
  Future<String> create(String name, String? displayName) async {
    _check();
    calls.add('create $name');
    lastDisplayName = displayName;
    household = HouseholdInfo(
      id: hid,
      name: name,
      ownerId: me,
      members: [
        HouseholdMember(userId: me, role: 'owner', displayName: displayName),
      ],
    );
    return hid;
  }

  @override
  Future<String> createInvite() async {
    _check();
    calls.add('invite');
    return 'ABCD1234';
  }

  @override
  Future<void> join(String code, String? displayName) async {
    _check();
    calls.add('join $code');
    lastDisplayName = displayName;
    household = HouseholdInfo(
      id: hid,
      name: 'Home',
      ownerId: partner,
      members: [
        const HouseholdMember(
          userId: partner,
          role: 'owner',
          displayName: 'Partner',
        ),
        HouseholdMember(userId: me, role: 'member', displayName: displayName),
      ],
    );
  }

  @override
  Future<LeaveResult> leave() async {
    _check();
    calls.add('leave');
    household = null;
    return leaveResult;
  }

  @override
  Future<void> removeMember(String userId) async {
    _check();
    calls.add('remove $userId');
  }

  @override
  Future<void> rename(String name) async {
    _check();
    calls.add('rename $name');
  }
}

HouseholdInfo twoPeople({String ownerId = partner}) => HouseholdInfo(
  id: hid,
  name: 'Home',
  ownerId: ownerId,
  members: const [
    HouseholdMember(userId: partner, role: 'owner', displayName: 'Partner'),
    HouseholdMember(userId: me, role: 'member', displayName: 'Me'),
  ],
);
