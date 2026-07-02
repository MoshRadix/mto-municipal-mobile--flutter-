import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/issue_provider.dart';
import '../providers/language_provider.dart';
import '../models/issue.dart';
import '../models/user.dart';
import '../widgets/issue_photo.dart';
import 'issue_updates_screen.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  String? _selectedStatus;
  String? _selectedAssignee;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.issue.status;
    _selectedAssignee = widget.issue.assignedTo;
    _titleController.text = widget.issue.title;
    _descriptionController.text = widget.issue.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleAdminUpdates() async {
    setState(() {
      _isSaving = true;
    });

    final provider = Provider.of<IssueProvider>(context, listen: false);
    final updates = <String, dynamic>{};

    if (_selectedStatus != widget.issue.status) {
      updates['status'] = _selectedStatus;
    }
    if (_selectedAssignee != widget.issue.assignedTo) {
      // API expects assigned_to (can be null for unassigned)
      updates['assigned_to'] = _selectedAssignee;
    }

    if (updates.isNotEmpty) {
      await provider.updateIssueStatus(widget.issue.id, updates);
    }

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      final language = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.locale == 'dv'
                ? 'ބަދަލުތައް ރައްކާކުރެވިއްޖެއެވެ'
                : 'Changes saved successfully!',
            style: const TextStyle(),
          ),
          backgroundColor: const Color(0xFF0D9488),
        ),
      );
    }
  }

  void _handleEditSubmit() async {
    setState(() {
      _isSaving = true;
    });

    final provider = Provider.of<IssueProvider>(context, listen: false);
    final updates = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': _selectedStatus,
    };

    await provider.updateIssueStatus(widget.issue.id, updates);

    setState(() {
      _isSaving = false;
      _isEditing = false;
    });

    if (mounted) {
      final language = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.locale == 'dv'
                ? 'މައުލޫމާތު އަޕްޑޭޓް ކުރެވިއްޖެއެވެ'
                : 'Issue updated successfully!',
            style: const TextStyle(),
          ),
          backgroundColor: const Color(0xFF0D9488),
        ),
      );
    }
  }

  void _handleDelete() async {
    final provider = Provider.of<IssueProvider>(context, listen: false);
    final t = Provider.of<LanguageProvider>(context, listen: false).t;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('delete')),
        content: Text(t('deleteConfirm'), style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isSaving = true;
      });

      await provider.deleteIssue(widget.issue.id);

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        Navigator.of(context).pop(); // Back to dashboard
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final issueProvider = Provider.of<IssueProvider>(context);

    final t = languageProvider.t;
    final isRtl = languageProvider.isRtl;
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return const Scaffold();

    // Check privileges
    final bool isAdmin = currentUser.isAdmin;
    final bool isCreator = widget.issue.createdBy == currentUser.id;
    final bool canEdit = (isAdmin || isCreator) && !widget.issue.isDraft;

    // Find assigned staff details
    User? assignedUser;
    if (widget.issue.assignedTo != null && issueProvider.staffList.isNotEmpty) {
      final index = issueProvider.staffList.indexWhere(
        (u) => u.id == widget.issue.assignedTo,
      );
      if (index != -1) {
        assignedUser = issueProvider.staffList[index];
      }
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF16323A),
          title: Text(
            t('viewDetails'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (isAdmin && !widget.issue.isDraft)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: _isSaving ? null : _handleDelete,
              ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo Carousel Card
                    _buildPhotoSection(),
                    const SizedBox(height: 16),

                    if (!widget.issue.isDraft) ...[
                      Card(
                        elevation: 1,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE6F7F5),
                            foregroundColor: Color(0xFF0D9488),
                            child: Icon(Icons.update),
                          ),
                          title: Text(
                            t('viewUpdates'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(t('viewUpdatesHint')),
                          trailing: Icon(
                            isRtl ? Icons.chevron_left : Icons.chevron_right,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    IssueUpdatesScreen(issue: widget.issue),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Detail Details Panel
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category and Status header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t('cat_${widget.issue.category}'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      _selectedStatus ?? widget.issue.status,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t(
                                      'status_${_selectedStatus ?? widget.issue.status}',
                                    ),
                                    style: TextStyle(
                                      color: _getStatusColor(
                                        _selectedStatus ?? widget.issue.status,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            if (_isEditing) ...[
                              // Edit Form fields
                              Text(
                                t('formRoadName'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t('formDescription'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _descriptionController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Creator status selection during edit
                              if (isCreator && !isAdmin) ...[
                                Text(
                                  t('colStatus'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text(
                                        t('status_pending'),
                                        style: const TextStyle(),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'in_progress',
                                      child: Text(
                                        t('status_in_progress'),
                                        style: const TextStyle(),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'resolved',
                                      child: Text(
                                        t('status_resolved'),
                                        style: const TextStyle(),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text(
                                        t('status_rejected'),
                                        style: const TextStyle(),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedStatus = val;
                                    });
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _isEditing = false),
                                    child: Text(
                                      t('cancel'),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _handleEditSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                    ),
                                    child: Text(
                                      t('save'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Standard Read Details View
                              _buildDetailRow(
                                t('colRoad'),
                                widget.issue.title,
                                Icons.title,
                              ),
                              _buildDetailRow(
                                t('colGps'),
                                widget.issue.gpsLocation,
                                Icons.location_on,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 18,
                                    color: Color(0xFF0D9488),
                                  ),
                                  onPressed: () => _copyToClipboard(
                                    widget.issue.gpsLocation,
                                    isRtl
                                        ? 'ކޯޑިނޭޓް ކޮޕީ ކުރެވިއްޖެ'
                                        : 'GPS coordinates copied!',
                                  ),
                                ),
                              ),
                              _buildDetailRow(
                                t('colDescription'),
                                widget.issue.description,
                                Icons.description,
                              ),
                              _buildDetailRow(
                                t('colCreatedAt'),
                                _formatDate(widget.issue.createdAt),
                                Icons.calendar_today,
                              ),

                              // Assignment Details
                              if (widget.issue.assignedTo != null)
                                _buildDetailRow(
                                  t('colAssignedTo'),
                                  assignedUser?.name ?? 'Loading staff...',
                                  Icons.person,
                                )
                              else
                                _buildDetailRow(
                                  t('colAssignedTo'),
                                  t('unassigned'),
                                  Icons.person_outline,
                                ),

                              // Creator details
                              _buildDetailRow(
                                t('colCreatedBy'),
                                widget.issue.createdBy == currentUser.id
                                    ? '${currentUser.name} (You)'
                                    : 'Staff Member',
                                Icons.edit_note,
                              ),

                              // Edit trigger
                              if (canEdit) ...[
                                const Divider(height: 24),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF0D9488),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Color(0xFF0D9488),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          t('editIssue'),
                                          style: const TextStyle(
                                            color: Color(0xFF0D9488),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Admin Action Controls Card
                    if (isAdmin && !_isEditing && !widget.issue.isDraft) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t('updateStatusTitle'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Status Dropdown
                              DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: InputDecoration(
                                  labelText: t('colStatus'),
                                  labelStyle: const TextStyle(),
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text(
                                      t('status_pending'),
                                      style: const TextStyle(),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text(
                                      t('status_in_progress'),
                                      style: const TextStyle(),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'resolved',
                                    child: Text(
                                      t('status_resolved'),
                                      style: const TextStyle(),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rejected',
                                    child: Text(
                                      t('status_rejected'),
                                      style: const TextStyle(),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedStatus = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),

                              // Assignee Dropdown (Admins only)
                              DropdownButtonFormField<String>(
                                value: _selectedAssignee,
                                decoration: InputDecoration(
                                  labelText: t('assignToUser'),
                                  labelStyle: const TextStyle(),
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      t('unassigned'),
                                      style: const TextStyle(),
                                    ),
                                  ),
                                  ...issueProvider.staffList.map((user) {
                                    return DropdownMenuItem(
                                      value: user.id,
                                      child: Text(
                                        '${user.name} (${t('role_${user.role}')})',
                                        style: const TextStyle(),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedAssignee = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Admin Save Button
                              ElevatedButton(
                                onPressed: _isSaving
                                    ? null
                                    : _handleAdminUpdates,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  t('save'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_isSaving)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF0D9488),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final List<String> localPhotos = widget.issue.localPhotoPaths;
    final List<String> remoteUrls = widget.issue.photoUrls;

    if (localPhotos.isEmpty && remoteUrls.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            const Text(
              'No photos attached',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final int imageCount = localPhotos.isNotEmpty
        ? localPhotos.length
        : remoteUrls.length;

    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: imageCount,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IssuePhoto(
                localPath: localPhotos.isNotEmpty ? localPhotos[index] : null,
                source: localPhotos.isEmpty ? remoteUrls[index] : null,
                width: double.infinity,
                height: 240,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Return standard representation
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
