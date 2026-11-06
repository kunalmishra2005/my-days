import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_days/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('welcome screen opens the memory library', (tester) async {
    await tester.pumpWidget(const MyDaysApp());

    expect(find.text('Your memories,\nyour universe.'), findsOneWidget);
    await tester.tap(find.text('Explore my memories'));
    await tester.pumpAndSettle();

    expect(find.text('My Memory Library'), findsOneWidget);
    expect(find.text('Your story starts here.'), findsOneWidget);
  });
}
