import 'dart:async';

import 'package:brand_governance/features/guidelines/presentation/brand_guidelines_screen.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreenWithStorage(
    WidgetTester tester,
    GuidelinesStorage storage,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: BrandGuidelinesScreen(storage: storage)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpScreenWithStorage(tester, SharedPreferencesGuidelinesStorage());
  }

  testWidgets('shows all guideline sections and local-storage notice', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.textContaining('Brand profile'), findsOneWidget);
    expect(find.textContaining('Tone and voice'), findsOneWidget);
    expect(find.textContaining('Approved terminology'), findsOneWidget);
    expect(find.textContaining('Required brand terms'), findsOneWidget);
    expect(find.textContaining('Prohibited words and phrases'), findsOneWidget);
    expect(find.textContaining('Verified brand facts'), findsOneWidget);
    expect(find.textContaining('not multi-user cloud storage'), findsOneWidget);
  });

  testWidgets('requires a brand name and blocks empty list entries', (
    tester,
  ) async {
    await pumpScreen(tester);

    await _scrollTo(tester, find.byKey(const Key('add_Approved term')));
    await tester.tap(find.byKey(const Key('add_Approved term')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a non-empty approved term.'), findsOneWidget);

    await _scrollTo(tester, find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a brand name to continue.'), findsOneWidget);
    expect(
      find.text('Please fix the highlighted fields before saving.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('brandNameField')),
      'Northstar',
    );
    await _scrollTo(tester, find.byKey(const Key('tone_custom')));
    await tester.tap(find.byKey(const Key('tone_custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Describe your custom tone.'), findsOneWidget);
    expect(
      find.text('Please fix the highlighted fields before saving.'),
      findsOneWidget,
    );
  });

  testWidgets('header Save calls storage and waits for successful completion', (
    tester,
  ) async {
    final storage = _ControlledGuidelinesStorage();
    await pumpScreenWithStorage(tester, storage);
    await tester.enterText(
      find.byKey(const Key('brandNameField')),
      'Northstar',
    );

    await tester.tap(find.byKey(const Key('headerSaveGuidelinesButton')));
    await tester.pump();

    expect(storage.saveCalls, 1);
    expect(storage.savedGuidelines?.brandName, 'Northstar');
    expect(find.text('Brand guidelines saved on this device.'), findsNothing);

    storage.saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.text('Brand guidelines saved on this device.'), findsOneWidget);
  });

  testWidgets('shows storage failures instead of swallowing them', (
    tester,
  ) async {
    final storage = _ControlledGuidelinesStorage()
      ..saveError = StateError('disk unavailable');
    await pumpScreenWithStorage(tester, storage);
    await tester.enterText(
      find.byKey(const Key('brandNameField')),
      'Northstar',
    );

    await tester.tap(find.byKey(const Key('saveGuidelinesButton')));
    await tester.pumpAndSettle();

    expect(storage.saveCalls, 1);
    expect(
      find.textContaining(
        'Could not save local guidelines: Bad state: disk unavailable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('saves and reloads the complete guideline profile', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('brandNameField')),
      'Northstar Studio',
    );
    await tester.enterText(
      find.byKey(const Key('brandDescriptionField')),
      'A thoughtful creative studio.',
    );
    await _scrollTo(tester, find.byKey(const Key('tone_custom')));
    await tester.tap(find.byKey(const Key('tone_custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customToneField')),
      'Curious and down-to-earth',
    );

    await _addEntry(tester, label: 'Approved term', value: 'community');
    await _addEntry(tester, label: 'Required term', value: 'Made for creators');
    await _addEntry(tester, label: 'Prohibited term', value: 'guaranteed');
    await _addEntry(
      tester,
      label: 'Verified fact',
      value: 'Founded in 2018 in Bengaluru',
    );

    await _scrollTo(tester, find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Brand guidelines saved on this device.'), findsOneWidget);

    await pumpScreen(tester);
    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('brandNameField')),
    );
    expect(nameField.controller?.text, 'Northstar Studio');
    expect(find.text('community'), findsOneWidget);
    expect(find.text('Made for creators'), findsOneWidget);
    expect(find.text('guaranteed'), findsOneWidget);
    expect(find.text('Founded in 2018 in Bengaluru'), findsOneWidget);

    await _scrollTo(tester, find.byTooltip('Remove community'));
    await tester.tap(find.byTooltip('Remove community'));
    await tester.pumpAndSettle();
    expect(find.text('community'), findsNothing);
  });

  testWidgets('renders the editor at a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BrandGuidelinesScreen(
          storage: SharedPreferencesGuidelinesStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Verified brand facts'), findsOneWidget);
  });
}

class _ControlledGuidelinesStorage implements GuidelinesStorage {
  final saveCompleter = Completer<void>();
  int saveCalls = 0;
  BrandGuidelines? savedGuidelines;
  Object? saveError;

  @override
  Future<BrandGuidelines> load() async => const BrandGuidelines();

  @override
  Future<void> save(BrandGuidelines guidelines) {
    saveCalls++;
    savedGuidelines = guidelines;
    final error = saveError;
    if (error != null) return Future<void>.error(error);
    return saveCompleter.future;
  }
}

Future<void> _addEntry(
  WidgetTester tester, {
  required String label,
  required String value,
}) async {
  final input = find.byKey(Key('input_$label'));
  await _scrollTo(tester, input);
  await tester.enterText(input, value);
  await tester.tap(find.byKey(Key('add_$label')));
  await tester.pumpAndSettle();
  expect(find.text(value), findsOneWidget);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
}
