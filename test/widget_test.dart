import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/main.dart';

void main() {
  testWidgets('Pubulotron app loads dashboard shell', (tester) async {
    await tester.pumpWidget(const PubulotronApp());

    expect(find.text('Pubulotron'), findsOneWidget);
    expect(find.text('Nouvelle création'), findsNWidgets(2));
  });
}
