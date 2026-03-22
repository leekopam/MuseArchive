import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_album_app/models/value_objects/release_date.dart';
import 'package:my_album_app/widgets/common_widgets.dart';

void main() {
  test('ReleaseDate.parse normalizes common inputs', () {
    expect(ReleaseDate.parse('2024.03.15').format(), '2024.03.15');
    expect(ReleaseDate.parse('202403').format(), '2024.03.01');
    expect(ReleaseDate.parse('').isValid, isFalse);
  });

  testWidgets('EmptyState renders the configured action', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EmptyState(
          icon: Icons.library_music_outlined,
          message: 'No albums yet',
          actionLabel: 'Add album',
          onAction: () {
            tapped = true;
          },
        ),
      ),
    );

    expect(find.text('No albums yet'), findsOneWidget);
    expect(find.text('Add album'), findsOneWidget);

    await tester.tap(find.text('Add album'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
