import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nala_addu/widgets/issue_photo.dart';

void main() {
  testWidgets('renders an API base64 data URI as an in-memory image', (
    tester,
  ) async {
    const transparentPixel =
        'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IssuePhoto(source: transparentPixel, width: 80, height: 80),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
