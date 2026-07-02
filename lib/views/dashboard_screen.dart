import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/issue_provider.dart';
import '../providers/language_provider.dart';
import '../models/issue.dart';
import '../models/issue_categories.dart';
import '../widgets/issue_photo.dart';
import 'issue_form_screen.dart';
import 'issue_detail_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final issueProvider = Provider.of<IssueProvider>(context, listen: false);
      issueProvider.loadIssues();
      issueProvider.loadDrafts();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser?.isAdmin ?? false) {
        issueProvider.loadStaffList();
      }
    });
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    Provider.of<IssueProvider>(context, listen: false).loadNextPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF10B981); // Emerald 500
      case 'in_progress':
        return const Color(0xFF3B82F6); // Blue 500
      case 'rejected':
        return const Color(0xFFEF4444); // Red 500
      case 'pending':
      default:
        return const Color(0xFFF59E0B); // Amber 500
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final issueProvider = Provider.of<IssueProvider>(context);

    final t = languageProvider.t;
    final isRtl = languageProvider.isRtl;
    final user = authProvider.currentUser;

    if (user == null) {
      // Safety redirect
      return const LoginScreen();
    }

    final issues = issueProvider.filteredIssues;

    // Calculate metrics
    final totalCount =
        (issueProvider.totalCount ?? issueProvider.remoteIssues.length) +
        issueProvider.localDrafts.length;
    final pendingCount =
        issueProvider.remoteIssues.where((i) => i.status == 'pending').length +
        issueProvider.localDrafts.length;
    final inProgressCount = issueProvider.remoteIssues
        .where((i) => i.status == 'in_progress')
        .length;
    final resolvedCount = issueProvider.remoteIssues
        .where((i) => i.status == 'resolved')
        .length;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF16323A),
          elevation: 0,
          title: Row(
            children: [
              Image.asset('assets/images/logo.png', height: 32, width: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('council'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF16323A),
                      ),
                    ),
                    Text(
                      '${t('welcome')}, ${user.name}',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF6F858B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await issueProvider.loadIssues();
            await issueProvider.loadDrafts();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (issueProvider.localDrafts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFFFEF3C7), // Amber 100
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off, color: Color(0xFFD97706)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isRtl
                                ? 'އޮފްލައިން ${issueProvider.localDrafts.length} މައްސަލަ ރައްކާކުރެވިފައި އެބަހުރި'
                                : 'You have ${issueProvider.localDrafts.length} pending offline issues.',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: issueProvider.isSyncing
                              ? null
                              : () => issueProvider.syncNow(),
                          child: issueProvider.isSyncing
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  isRtl ? 'ސިންކް ކުރޭ' : 'Sync Now',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.05,
                        children: [
                          _buildStatCard(
                            t('all'),
                            totalCount.toString(),
                            const Color(0xFF16323A),
                            Icons.dashboard_rounded,
                          ),
                          _buildStatCard(
                            t('status_pending'),
                            pendingCount.toString(),
                            const Color(0xFFF59E0B),
                            Icons.schedule_rounded,
                          ),
                          _buildStatCard(
                            t('status_in_progress'),
                            inProgressCount.toString(),
                            const Color(0xFF3B82F6),
                            Icons.autorenew_rounded,
                          ),
                          _buildStatCard(
                            t('status_resolved'),
                            resolvedCount.toString(),
                            const Color(0xFF10B981),
                            Icons.task_alt_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (issueProvider.weeklyTopCategory case final summary?)
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () =>
                              issueProvider.setCategoryFilter(summary.category),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF087F8C), Color(0xFF16A6A1)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.insights_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${summary.count} ${t('cat_${summary.category}').toLowerCase()} reports this week',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isRtl ? 'މައްސަލަތަކުގެ ލިސްޓް' : 'Issues Log',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                            icon: Icon(
                              _showFilters
                                  ? Icons.filter_list_off
                                  : Icons.filter_list,
                              size: 18,
                              color: const Color(0xFF0D9488),
                            ),
                            label: Text(
                              isRtl ? 'ފިލްޓަރުތައް' : 'Filters',
                              style: const TextStyle(
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Group issues',
                            initialValue: issueProvider.groupBy,
                            onSelected: issueProvider.setGroupBy,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'date',
                                child: Text('Group by date'),
                              ),
                              PopupMenuItem(
                                value: 'title',
                                child: Text('Group by title'),
                              ),
                              PopupMenuItem(
                                value: 'category',
                                child: Text('Group by category'),
                              ),
                            ],
                            icon: const Icon(Icons.view_agenda_outlined),
                          ),
                        ],
                      ),

                      // Filter Panel
                      if (_showFilters) ...[
                        const SizedBox(height: 8),
                        _buildFilterPanel(context, issueProvider, t),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (issueProvider.isLoading && issues.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (issues.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t('noIssues'),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      final groupKey = issueProvider.groupKeyFor(issue);
                      final previousKey = index == 0
                          ? null
                          : issueProvider.groupKeyFor(issues[index - 1]);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (groupKey != previousKey)
                            Padding(
                              padding: EdgeInsets.only(
                                top: index == 0 ? 0 : 10,
                                bottom: 8,
                              ),
                              child: Text(
                                issueProvider.groupBy == 'category'
                                    ? t('cat_$groupKey')
                                    : groupKey,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6F858B),
                                ),
                              ),
                            ),
                          _buildIssueItem(context, issue, t, isRtl),
                        ],
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: issueProvider.isLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : !issueProvider.hasMore && issues.isNotEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(24, 8, 24, 100),
                          child: Center(
                            child: Text(
                              'You’re all caught up',
                              style: TextStyle(color: Color(0xFF8CA0A8)),
                            ),
                          ),
                        )
                      : const SizedBox(height: 100),
                ),
              ),
            ],
          ),
        ),

        // Report button (Visible for Admin and Entry/Staff users only)
        floatingActionButton: (!user.isReadOnly)
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const IssueFormScreen()),
                  );
                },
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_a_photo),
                label: Text(
                  t('addIssue'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6F858B),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(
    BuildContext context,
    IssueProvider provider,
    String Function(String) t,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search issue title
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t('searchRoad'),
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) {
                provider.setTitleFilter(val);
              },
            ),
            const SizedBox(height: 10),

            // Dropdowns (Category, Status, Assignee)
            Row(
              children: [
                // Category Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: provider.categoryFilter,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          t('filterCategory'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      ...issueCategories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            t('cat_$category'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) provider.setCategoryFilter(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Status Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: provider.statusFilter,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          t('filterStatus'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(
                          t('status_pending'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text(
                          t('status_in_progress'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text(
                          t('status_resolved'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text(
                          t('status_rejected'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) provider.setStatusFilter(val);
                    },
                  ),
                ),
              ],
            ),

            // Clear Filters Button
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                child: Text(
                  Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).locale ==
                          'dv'
                      ? 'ފިލްޓަރުތައް ފޮހެލާ'
                      : 'Clear Filters',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueItem(
    BuildContext context,
    Issue issue,
    String Function(String) t,
    bool isRtl,
  ) {
    final photoWidget = IssuePhoto(
      localPath: issue.localPhotoPaths.isEmpty
          ? null
          : issue.localPhotoPaths.first,
      source: issue.photoUrls.isEmpty ? null : issue.photoUrls.first,
      width: 76,
      height: 76,
      borderRadius: BorderRadius.circular(14),
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2EBED)),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: photoWidget,
        title: Row(
          children: [
            Expanded(
              child: Text(
                t('cat_${issue.category}'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Offline/Draft label
            if (issue.isDraft)
              Container(
                margin: const EdgeInsets.only(left: 4, right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  isRtl ? 'އޮފްލައިން' : 'Draft',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(issue.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                t('status_${issue.status}'),
                style: TextStyle(
                  color: _getStatusColor(issue.status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Color(0xFF6F858B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.gpsLocation.trim().isEmpty ||
                              issue.gpsLocation == '0,0'
                          ? (isRtl ? 'ލޮކޭޝަން ނުލިބޭ' : 'Location unavailable')
                          : issue.gpsLocation,
                      textDirection:
                          (issue.gpsLocation.trim().isEmpty ||
                              issue.gpsLocation == '0,0')
                          ? (isRtl ? TextDirection.rtl : TextDirection.ltr)
                          : TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6F858B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                issue.description,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => IssueDetailScreen(issue: issue)),
          );
        },
      ),
    );
  }
}
