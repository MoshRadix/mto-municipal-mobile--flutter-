import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/issue_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _savingUrl = false;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final url = await _apiService.getBaseUrl();
    _urlController.text = url;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _saveUrl() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _savingUrl = true;
    });

    await _apiService.setBaseUrl(url);

    // Reload issues in case URL has changed
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);
    await issueProvider.loadIssues();

    setState(() {
      _savingUrl = false;
    });

    if (mounted) {
      final t = Provider.of<LanguageProvider>(context, listen: false).t;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('save') == 'Save Changes'
                ? 'API URL updated successfully!'
                : 'އޭޕީއައި ޔޫއާރްއެލް އަޕްޑޭޓް ކުރެވިއްޖެ',
            style: const TextStyle(),
          ),
          backgroundColor: const Color(0xFF0D9488),
        ),
      );
    }
  }

  void _resetUrl() async {
    setState(() {
      _savingUrl = true;
    });

    await _apiService.setBaseUrl(ApiService.defaultBaseUrl);
    _urlController.text = ApiService.defaultBaseUrl;

    // Reload issues in case URL has changed
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);
    await issueProvider.loadIssues();

    setState(() {
      _savingUrl = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'API URL reset to production Vercel server.',
            style: TextStyle(),
          ),
        ),
      );
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

    if (user == null) return const Scaffold();

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: Text(
            languageProvider.locale == 'dv' ? 'ސެޓިންގްސް' : 'App Settings',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User info header card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(
                          0xFF0D9488,
                        ).withOpacity(0.15),
                        child: const Icon(
                          Icons.person,
                          size: 36,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0F172A,
                                ).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t('role_${user.role}'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Language Section
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
                      Text(
                        isRtl ? 'ބަސް ބަދަލުކުރުން' : 'Language preference',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  'English',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: languageProvider.locale == 'en',
                              onSelected: (selected) {
                                if (selected)
                                  languageProvider.setLanguage('en');
                              },
                              selectedColor: const Color(
                                0xFF0D9488,
                              ).withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: languageProvider.locale == 'en'
                                    ? const Color(0xFF0D9488)
                                    : Colors.grey[700],
                              ),
                              checkmarkColor: const Color(0xFF0D9488),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  'ދިވެހި',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: languageProvider.locale == 'dv',
                              onSelected: (selected) {
                                if (selected)
                                  languageProvider.setLanguage('dv');
                              },
                              selectedColor: const Color(
                                0xFF0D9488,
                              ).withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: languageProvider.locale == 'dv'
                                    ? const Color(0xFF0D9488)
                                    : Colors.grey[700],
                              ),
                              checkmarkColor: const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Offline Sync Manager
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
                      Text(
                        isRtl ? 'އޮފްލައިން ސިންކް' : 'Offline Operations',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.cloud_sync,
                          color: Color(0xFF0D9488),
                        ),
                        title: Text(
                          isRtl ? 'ބެކްގްރައުންޑް ސިންކް' : 'Sync Status',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          issueProvider.localDrafts.isEmpty
                              ? (isRtl
                                    ? 'ހުރިހާ މައުލޫމާތެއް ވަނީ ސިންކް ކުރެވިފައި'
                                    : 'All issue drafts are synced.')
                              : (isRtl
                                    ? '${issueProvider.localDrafts.length} މައްސަލަ ސިންކް ނުވެ އެބަހުރި'
                                    : 'You have ${issueProvider.localDrafts.length} issues waiting to upload.'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: issueProvider.localDrafts.isNotEmpty
                            ? ElevatedButton(
                                onPressed: issueProvider.isSyncing
                                    ? null
                                    : () => issueProvider.syncNow(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                ),
                                child: issueProvider.isSyncing
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        isRtl ? 'ސިންކް ކުރޭ' : 'Sync Now',
                                        style: const TextStyle(),
                                      ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // API Endpoint Configuration
              Card(
                elevation: 1,
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
                        isRtl ? 'ސާވަރ ކޮންފިގަރޭޝަން' : 'Server Configuration',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _savingUrl ? null : _resetUrl,
                            child: Text(
                              'Reset Default',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _savingUrl ? null : _saveUrl,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                            ),
                            child: _savingUrl
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(t('save'), style: const TextStyle()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
