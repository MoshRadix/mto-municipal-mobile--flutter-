# Nala Addu

Addu City municipal issue reporting app.

## Scalable issue pipeline

- Issues load in pages of 30 through `ApiService.fetchIssuesPage`.
- The API client accepts both a plain legacy array and a paginated
  `{ items, total, hasMore }` response. Legacy arrays are sliced locally.
- `IssueProvider` deduplicates pages, tracks loading/terminal states, and
  exposes filtered, grouped, and weekly-summary views.
- The dashboard uses `CustomScrollView` and `SliverList`, so only visible issue
  cards are built.
- Hive retains the 500 most recently updated issues and maintains secondary
  indexes for road, category, and status.
- Offline reports remain in a durable Hive queue. Connectivity changes,
  WorkManager (every 15 minutes), and the manual **Sync Now** actions process
  the queue in batches of five.
- Watermarked photos are resized and JPEG-compressed before upload.

For true network-level pagination, the server should honor `page` and `limit`
and preferably return:

```json
{
  "items": [],
  "total": 1200,
  "hasMore": true
}
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
