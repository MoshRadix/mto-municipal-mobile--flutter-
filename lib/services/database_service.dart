import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/issue.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static const int maxCachedIssues = 500;
  static const String kSettingsBox = 'settings_box';
  static const String kDraftsBox = 'drafts_box';
  static const String kCachedIssuesBox = 'cached_issues_box';
  static const String kIssueIndexBox = 'issue_index_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(kSettingsBox);
    await Hive.openBox(kDraftsBox);
    await Hive.openBox(kCachedIssuesBox);
    await Hive.openBox(kIssueIndexBox);
  }

  // --- Settings ---
  Future<String?> getSetting(String key) async {
    final box = Hive.box(kSettingsBox);
    return box.get(key) as String?;
  }

  Future<void> saveSetting(String key, String value) async {
    final box = Hive.box(kSettingsBox);
    await box.put(key, value);
  }

  Future<void> removeSetting(String key) async {
    final box = Hive.box(kSettingsBox);
    await box.delete(key);
  }

  // --- Offline Drafts ---
  Future<List<Issue>> getDrafts() async {
    final box = Hive.box(kDraftsBox);
    final List<Issue> drafts = [];
    for (var key in box.keys) {
      final String? jsonStr = box.get(key) as String?;
      if (jsonStr != null) {
        try {
          drafts.add(Issue.fromJson(json.decode(jsonStr)));
        } catch (e) {
          debugPrint('Error parsing local draft: $e');
        }
      }
    }
    return drafts;
  }

  Future<void> saveDraft(Issue issue) async {
    final box = Hive.box(kDraftsBox);
    final updatedIssue = issue.copyWith(isDraft: true);
    await box.put(updatedIssue.id, json.encode(updatedIssue.toJson()));
  }

  Future<void> deleteDraft(String id) async {
    final box = Hive.box(kDraftsBox);
    await box.delete(id);
  }

  Future<void> clearDrafts() async {
    final box = Hive.box(kDraftsBox);
    await box.clear();
  }

  // --- Cached Remote Issues (For Offline viewing of dashboard) ---
  Future<List<Issue>> getCachedIssues({
    int offset = 0,
    int? limit,
    String? title,
    String? category,
    String? status,
  }) async {
    final box = Hive.box(kCachedIssuesBox);
    final indexBox = Hive.box(kIssueIndexBox);
    final List<Issue> issues = [];
    Set<dynamic>? candidateIds;

    void intersectIndex(String key) {
      final ids = Set<dynamic>.from(indexBox.get(key, defaultValue: const []));
      candidateIds = candidateIds == null
          ? ids
          : candidateIds!.intersection(ids);
    }

    if (category != null && category != 'all') {
      intersectIndex('category:${category.toLowerCase()}');
    }
    if (status != null && status != 'all') {
      intersectIndex('status:${status.toLowerCase()}');
    }
    final keys = candidateIds ?? box.keys.toSet();
    for (final key in keys) {
      final String? jsonStr = box.get(key) as String?;
      if (jsonStr != null) {
        try {
          final issue = Issue.fromJson(json.decode(jsonStr));
          if (title == null ||
              title.trim().isEmpty ||
              issue.title.toLowerCase().contains(title.trim().toLowerCase())) {
            issues.add(issue);
          }
        } catch (e) {
          debugPrint('Error parsing cached issue: $e');
        }
      }
    }
    // Sort cached issues by date descending
    issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sliced = issues.skip(offset);
    return limit == null ? sliced.toList() : sliced.take(limit).toList();
  }

  Future<void> cacheIssues(List<Issue> issues, {bool replace = false}) async {
    final box = Hive.box(kCachedIssuesBox);
    if (replace) await box.clear();
    final entries = <dynamic, dynamic>{
      for (final issue in issues) issue.id: json.encode(issue.toJson()),
    };
    await box.putAll(entries);
    if (box.length > maxCachedIssues) {
      final datedKeys = <(dynamic, DateTime)>[];
      for (final key in box.keys) {
        try {
          final value = box.get(key) as String;
          final issue = Issue.fromJson(json.decode(value));
          datedKeys.add((key, issue.updatedAt));
        } catch (_) {
          datedKeys.add((key, DateTime.fromMillisecondsSinceEpoch(0)));
        }
      }
      datedKeys.sort((a, b) => b.$2.compareTo(a.$2));
      await box.deleteAll(
        datedKeys.skip(maxCachedIssues).map((entry) => entry.$1),
      );
    }
    await _rebuildIssueIndexes();
  }

  Future<void> deleteCachedIssue(String id) async {
    await Hive.box(kCachedIssuesBox).delete(id);
    await _rebuildIssueIndexes();
  }

  Future<void> _rebuildIssueIndexes() async {
    final box = Hive.box(kCachedIssuesBox);
    final indexBox = Hive.box(kIssueIndexBox);
    final indexes = <String, List<String>>{};

    void add(String key, String id) {
      indexes.putIfAbsent(key, () => <String>[]).add(id);
    }

    for (final value in box.values) {
      try {
        final issue = Issue.fromJson(json.decode(value as String));
        add('title:${issue.title.trim().toLowerCase()}', issue.id);
        add('category:${issue.category.toLowerCase()}', issue.id);
        add('status:${issue.status.toLowerCase()}', issue.id);
      } catch (_) {
        // Ignore damaged cache records; valid entries remain indexed.
      }
    }
    await indexBox.clear();
    await indexBox.putAll(indexes);
  }

  Future<void> clearCache() async {
    final box = Hive.box(kCachedIssuesBox);
    await box.clear();
    await Hive.box(kIssueIndexBox).clear();
  }
}
