import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../models/issue_update.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class IssueUpdatesScreen extends StatefulWidget {
  final Issue issue;

  const IssueUpdatesScreen({super.key, required this.issue});

  @override
  State<IssueUpdatesScreen> createState() => _IssueUpdatesScreenState();
}

class _IssueUpdatesScreenState extends State<IssueUpdatesScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<IssueUpdate> _updates = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool get _isIncomplete =>
      widget.issue.status == 'pending' || widget.issue.status == 'in_progress';

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUpdates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updates = await _apiService.fetchIssueUpdates(widget.issue.id);
      if (!mounted) return;
      setState(() => _updates = updates);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final update = await _apiService.addIssueUpdate(
        widget.issue.id,
        _notesController.text.trim(),
      );
      if (!mounted) return;
      _notesController.clear();
      setState(() => _updates = [update, ..._updates]);
      final t = context.read<LanguageProvider>().t;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('updateAdded')),
          backgroundColor: const Color(0xFF0D9488),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final t = language.t;
    final canAdd =
        user != null && (user.isEntry || user.isAdmin) && _isIncomplete;

    return Directionality(
      textDirection: language.isRtl
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF16323A),
          title: Text(
            t('issueUpdates'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadUpdates,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildIssueSummary(t),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFFFFEDED),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!)),
                        TextButton(
                          onPressed: _loadUpdates,
                          child: Text(t('retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (canAdd) ...[
                const SizedBox(height: 12),
                _buildComposer(t),
              ] else if (!_isIncomplete) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: const Color(0xFFFFF7E6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t('updatesClosed'))),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                t('updateHistory'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_updates.isEmpty)
                _buildEmptyState(t)
              else
                ..._updates.map(_buildUpdateCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueSummary(String Function(String) t) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE6F7F5),
              foregroundColor: Color(0xFF0D9488),
              child: Icon(Icons.build_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.issue.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${t('cat_${widget.issue.category}')} · '
                    '${t('status_${widget.issue.status}')}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(String Function(String) t) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('addUpdate'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t('updateNotes'),
                  hintText: t('updateNotesHint'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t('updateNotes');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submitUpdate,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(t('addUpdate')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(IssueUpdate update) {
    final formatter = DateFormat('d MMM yyyy, HH:mm');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              update.notes,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Color(0xFF1E293B),
              ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _metadata(Icons.person_outline, update.author.name),
                _metadata(
                  Icons.schedule,
                  formatter.format(update.createdAt.toLocal()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metadata(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String Function(String) t) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 42,
              color: Colors.blueGrey.shade200,
            ),
            const SizedBox(height: 10),
            Text(
              t('noUpdates'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
