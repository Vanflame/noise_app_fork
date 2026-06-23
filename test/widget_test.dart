import 'package:flutter_test/flutter_test.dart';
import 'package:noise_app/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const NoiseApp());
    expect(find.text('Smart Classroom Noise Monitor'), findsNothing);
  });
}