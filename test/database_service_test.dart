import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nala_addu/models/issue.dart';
import 'package:nala_addu/services/database_service.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseService database;

  Issue issue(String id, String title, String category, String status) {
    return Issue(
      id: id,
      photoUrls: const [],
      gpsLocation: '0,0',
      title: title,
      category: category,
      description: 'Test',
      status: status,
      createdBy: 'tester',
      updatedBy: 'tester',
      createdAt: DateTime.utc(2026, 1, int.parse(id)),
      updatedAt: DateTime.utc(2026, 1, int.parse(id)),
    );
  }

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('mto_hive_test');
    Hive.init(tempDirectory.path);
    await Hive.openBox(DatabaseService.kCachedIssuesBox);
    await Hive.openBox(DatabaseService.kIssueIndexBox);
    database = DatabaseService();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('merges pages and queries category/status indexes', () async {
    await database.cacheIssues([
      issue('1', 'Main Road', 'street_lights', 'pending'),
      issue('2', 'Harbour Road', 'drainage_issues', 'resolved'),
    ]);
    await database.cacheIssues([
      issue('3', 'Main Road', 'street_lights', 'resolved'),
    ]);

    final streetLights = await database.getCachedIssues(
      category: 'street_lights',
    );
    final resolved = await database.getCachedIssues(status: 'resolved');
    final titleSearch = await database.getCachedIssues(title: 'main');

    expect(streetLights.map((item) => item.id), containsAll(['1', '3']));
    expect(resolved.map((item) => item.id), containsAll(['2', '3']));
    expect(titleSearch.map((item) => item.id), containsAll(['1', '3']));
  });
}
