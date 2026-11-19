import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/providers/user_profile_provider.dart';
import 'package:nutrilens/services/profile_store.dart';

class FakeStorage implements ProfileStorage {
  Map<String, dynamic>? data;
  int writes = 0;
  bool wiped = false;

  FakeStorage([this.data]);

  @override
  Future<Map<String, dynamic>?> read() async => data;

  @override
  Future<void> write(Map<String, dynamic> d) async {
    data = d;
    writes++;
  }

  @override
  Future<void> wipe() async {
    data = null;
    wiped = true;
  }
}

void main() {
  test('attachStorage restores a saved profile', () async {
    final storage = FakeStorage({
      'name': 'Asha',
      'bmi': 22.5,
      'age': 30,
      'allergies': ['Peanuts'],
      'medications': ['Amlodipine 5mg'],
    });
    final profile = UserProfileProvider(storage: storage);
    await profile.attachStorage();
    expect(profile.name, 'Asha');
    expect(profile.bmi, 22.5);
    expect(profile.age, 30);
    expect(profile.allergies, ['Peanuts']);
    expect(profile.medications, ['Amlodipine 5mg']);
  });

  test('changes are not saved before storage is attached', () async {
    final storage = FakeStorage();
    final profile = UserProfileProvider(storage: storage);
    profile.updateName('Ravi');
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, 0);
  });

  test('changes are saved after storage is attached', () async {
    final storage = FakeStorage();
    final profile = UserProfileProvider(storage: storage);
    await profile.attachStorage();
    profile.updateName('Ravi');
    await Future<void>.delayed(Duration.zero);
    expect(storage.data?['name'], 'Ravi');
  });

  test('signing out clears memory but keeps the stored profile', () async {
    final storage = FakeStorage({'name': 'Asha'});
    final profile = UserProfileProvider(storage: storage);
    await profile.attachStorage();
    profile.clearAll();
    expect(profile.name, '');
    expect(storage.data?['name'], 'Asha');

    final writesBefore = storage.writes;
    profile.updateName('x');
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, writesBefore);
  });

  test('deleteEverything wipes storage and memory', () async {
    final storage = FakeStorage({'name': 'Asha'});
    final profile = UserProfileProvider(storage: storage);
    await profile.attachStorage();
    await profile.deleteEverything();
    expect(storage.wiped, isTrue);
    expect(storage.data, isNull);
    expect(profile.name, '');
  });

  test('malformed stored data falls back to defaults', () async {
    final storage = FakeStorage({'allergies': 'peanuts', 'bmi': 'x', 'age': null});
    final profile = UserProfileProvider(storage: storage);
    await profile.attachStorage();
    expect(profile.allergies, isEmpty);
    expect(profile.bmi, 0);
    expect(profile.age, 0);
  });
}
