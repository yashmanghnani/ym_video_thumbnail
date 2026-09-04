import 'package:flutter_test/flutter_test.dart';
import 'package:video_thumbnail_example/main.dart';

void main() {
  testWidgets('renders the thumbnail demo', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Thumbnail Plugin Example'), findsOneWidget);
    expect(find.byTooltip('Generate data thumbnail'), findsOneWidget);
    expect(find.byTooltip('Generate file thumbnail'), findsOneWidget);
  });
}
