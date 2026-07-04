import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/issue.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class IssueProvider with ChangeNotifier {
  final ApiService _apiService;
  final DatabaseService _dbService;
  final SyncService _syncService;

  List<Issue> _remoteIssues = [];
  List<Issue> _localDrafts = [];
  List<User> _staffList = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int? _totalCount;
  static const int pageSize = 30;
  String? _errorMessage;
  Timer? _searchDebounce;

  // Filters
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _titleFilter = '';
  String _assignedFilter = 'all';
  String _groupBy = 'date';

  IssueProvider({
    required this._apiService,
    required this._dbService,
    required this._syncService,
  }) {
    // Configure sync listeners
    _syncService.onSyncComplete = () {
      debugPrint('Sync succeeded, reloading issues...');
      loadIssues();
      loadDrafts();
    };
    _syncService.onSyncError = (msg) {
      _errorMessage = msg;
      notifyListeners();
    };

    // Load initial data
    loadDrafts();
  }

  // Getters
  List<Issue> get remoteIssues => _remoteIssues;
  List<Issue> get localDrafts => _localDrafts;
  List<User> get staffList => _staffList;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int? get totalCount => _totalCount;
  bool get isSyncing => _syncService.isSyncing;
  String? get errorMessage => _errorMessage;

  String get statusFilter => _statusFilter;
  String get categoryFilter => _categoryFilter;
  String get titleFilter => _titleFilter;
  String get assignedFilter => _assignedFilter;
  String get groupBy => _groupBy;

  // Combined and filtered issues
  List<Issue> get filteredIssues {
    // Merge drafts and remote issues
    // Drafts always appear at the top
    final List<Issue> combined = [..._localDrafts, ..._remoteIssues];

    final filtered = combined.where((issue) {
      // 1. Status Filter (Drafts have status 'pending' locally)
      if (_statusFilter != 'all') {
        if (issue.status != _statusFilter) return false;
      }

      // 2. Category Filter
      if (_categoryFilter != 'all') {
        if (issue.category != _categoryFilter) return false;
      }

      // 3. Issue title filter
      if (_titleFilter.isNotEmpty) {
        if (!issue.title.toLowerCase().contains(_titleFilter.toLowerCase())) {
          return false;
        }
      }

      // 4. Assigned User Filter
      if (_assignedFilter != 'all') {
        if (_assignedFilter == 'unassigned') {
          if (issue.assignedTo != null) return false;
        } else {
          if (issue.assignedTo != _assignedFilter) return false;
        }
      }

      return true;
    }).toList();

    switch (_groupBy) {
      case 'title':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'category':
        filtered.sort((a, b) => a.category.compareTo(b.category));
        break;
      case 'date':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return filtered;
  }

  String groupKeyFor(Issue issue) {
    switch (_groupBy) {
      case 'title':
        return issue.title.trim().isEmpty ? 'Untitled issue' : issue.title;
      case 'category':
        return issue.category;
      case 'date':
      default:
        final now = DateTime.now();
        final date = DateTime(
          issue.createdAt.year,
          issue.createdAt.month,
          issue.createdAt.day,
        );
        final today = DateTime(now.year, now.month, now.day);
        final days = today.difference(date).inDays;
        if (days == 0) return 'Today';
        if (days == 1) return 'Yesterday';
        if (days < 7) return 'This week';
        return '${issue.createdAt.year}-${issue.createdAt.month.toString().padLeft(2, '0')}';
    }
  }

  ({String category, int count})? get weeklyTopCategory {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final counts = <String, int>{};
    for (final issue in _remoteIssues) {
      if (issue.createdAt.isAfter(cutoff)) {
        counts.update(issue.category, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    if (counts.isEmpty) return null;
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (category: top.key, count: top.value);
  }

  // Setters for filters
  void setStatusFilter(String value) {
    _statusFilter = value;
    loadIssues();
  }

  void setCategoryFilter(String value) {
    _categoryFilter = value;
    loadIssues();
  }

  void setTitleFilter(String value) {
    _titleFilter = value;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), loadIssues);
  }

  void setAssignedFilter(String value) {
    _assignedFilter = value;
    loadIssues();
  }

  void setGroupBy(String value) {
    _groupBy = value;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = 'all';
    _categoryFilter = 'all';
    _titleFilter = '';
    _assignedFilter = 'all';
    loadIssues();
  }

  // Load drafts
  Future<void> loadDrafts() async {
    try {
      _localDrafts = await _dbService.getDrafts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading drafts: $e');
    }
  }

  // Load issues
  Future<void> loadIssues({bool refresh = true}) async {
    if (refresh) {
      if (_isLoading) return;
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
      _totalCount = null;
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await _apiService.fetchIssuesPage(
        page: nextPage,
        pageSize: pageSize,
        status: _statusFilter,
        category: _categoryFilter,
        title: _titleFilter,
        assignedTo: _assignedFilter,
      );
      final existing = refresh
          ? <String, Issue>{}
          : {for (final issue in _remoteIssues) issue.id: issue};
      for (final issue in result.items) {
        existing[issue.id] = issue;
      }
      _remoteIssues = existing.values.toList();
      _currentPage = nextPage;
      _hasMore = result.hasMore;
      _totalCount = result.total;
      await _dbService.cacheIssues(result.items);
    } catch (e) {
      debugPrint('Online fetch failed: $e, loading from cache...');
      _errorMessage =
          'Could not update issues from server. Displaying offline cached data.';
      final cached = await _dbService.getCachedIssues(
        offset: refresh ? 0 : _remoteIssues.length,
        limit: pageSize,
        title: _titleFilter,
        category: _categoryFilter,
        status: _statusFilter,
      );
      if (refresh) {
        _remoteIssues = cached;
      } else {
        final existing = {for (final issue in _remoteIssues) issue.id: issue};
        for (final issue in cached) {
          existing[issue.id] = issue;
        }
        _remoteIssues = existing.values.toList();
      }
      _hasMore = cached.length == pageSize;
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() => loadIssues(refresh: false);

  // Load staff list (admin only)
  Future<void> loadStaffList() async {
    try {
      final list = await _apiService.fetchUsers();
      _staffList = list;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading staff directory: $e');
    }
  }

  // Submit issue (Offline first)
  Future<bool> submitIssue({
    required String title,
    required String category,
    required String description,
    required String gpsLocation,
    required List<String> localPhotoPaths,
    required String currentUserId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Try online submission
      await _apiService.createIssue(
        title: title,
        category: category,
        description: description,
        gpsLocation: gpsLocation,
        localPhotoPaths: localPhotoPaths,
      );

      // submission succeeded online
      await loadIssues();
      _isLoading = false;
      return true;
    } catch (e) {
      // 2. Online failed (e.g. no internet/timeout), save offline as draft
      debugPrint('Online submission failed: $e. Saving offline as draft...');

      final offlineIssue = Issue(
        id: const Uuid().v4(),
        photoUrls: [], // No remote URLs yet
        gpsLocation: gpsLocation,
        title: title,
        category: category,
        description: description,
        status: 'pending',
        createdBy: currentUserId,
        updatedBy: currentUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDraft: true,
        localPhotoPaths: localPhotoPaths,
      );

      await _dbService.saveDraft(offlineIssue);
      await loadDrafts();

      _isLoading = false;
      return false; // Returns false to indicate offline save
    }
  }

  // Update Status & Details (online only)
  Future<void> updateIssueStatus(
    String id,
    Map<String, dynamic> updates,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _apiService.updateIssue(id, updates);

      // Update item in local lists
      final index = _remoteIssues.indexWhere((item) => item.id == id);
      if (index != -1) {
        _remoteIssues[index] = updated;
      }

      // Recache
      await _dbService.cacheIssues(_remoteIssues);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete Issue (online only, admin only)
  Future<void> deleteIssue(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.deleteIssue(id);
      _remoteIssues.removeWhere((item) => item.id == id);
      await _dbService.deleteCachedIssue(id);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear local error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Trigger manual sync
  Future<void> syncNow() async {
    _errorMessage = null;
    notifyListeners();
    await _syncService.syncNow();
  }
}
