import 'issue.dart';

class IssuePage {
  const IssuePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.total,
  });

  final List<Issue> items;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int? total;
}
