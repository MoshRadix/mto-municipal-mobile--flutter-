import 'user.dart';

class IssueUpdate {
  final String id;
  final String issueId;
  final String notes;
  final DateTime createdAt;
  final User author;

  const IssueUpdate({
    required this.id,
    required this.issueId,
    required this.notes,
    required this.createdAt,
    required this.author,
  });

  factory IssueUpdate.fromJson(Map<String, dynamic> json) {
    return IssueUpdate(
      id: json['id'] as String,
      issueId: json['issue_id'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      author: User.fromJson(json['author'] as Map<String, dynamic>),
    );
  }
}
