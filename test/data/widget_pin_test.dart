import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/widget_store.dart';

/// docs/15 QP-C1: the seam the widget prompt asks three questions through —
/// can this launcher add a widget, please add one, and how many are placed.
///
/// `HomeWidgetStore` is exercised over the plugin's real channel name with a
/// scripted answer, in the shape the plugin's Kotlin actually produces (read
/// from `home_widget` 0.9.4, the version `pubspec.lock` pins). That is the point
/// of these tests: the failure mode of this class is a silent wrong answer, and
/// the widest hole is the class name — Android reports
/// `ComponentName.shortClassName`, `.widget.CirrusWidgetProvider`, never the
/// fully-qualified name the manifest declares.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? answer;

  setUp(() {
    calls.clear();
    answer = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return answer!(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const store = HomeWidgetStore();

  Map<String, Object?> cirrus(int id) => {
    'widgetId': id,
    // `ComponentName.getShortClassName()`: the package prefix is cut off.
    'androidClassName': '.widget.CirrusWidgetProvider',
    'label': 'Cirrus',
  };

  group('canPin', () {
    test('is what the launcher answers', () async {
      answer = (call) => true;
      expect(await store.canPin(), isTrue);
      expect(calls.single.method, 'isRequestPinWidgetSupported');

      answer = (call) => false;
      expect(await store.canPin(), isFalse);
    });

    test('reads the plugin\'s null as no', () async {
      // `isRequestPinWidgetSupported()` is `bool?`; a null must never be
      // mistaken for a yes.
      answer = (call) => null;
      expect(await store.canPin(), isFalse);
    });

    test('is no when the channel fails', () async {
      answer = (call) => throw PlatformException(code: 'boom');
      expect(await store.canPin(), isFalse);
    });
  });

  group('requestPin', () {
    test('addresses the provider by its qualified name, and only that', () async {
      answer = (call) => call.method == 'isRequestPinWidgetSupported' ? true : null;

      expect(await store.requestPin(), isTrue);

      final request = calls.singleWhere((c) => c.method == 'requestPinWidget');
      final args = Map<String, Object?>.from(request.arguments as Map);
      // `androidName` would be prefixed with the package and throw
      // ClassNotFoundException, `name` is the wrong lookup — only the
      // qualified name resolves the provider the manifest declares.
      expect(args['qualifiedAndroidName'], HomeWidgetStore.androidProvider);
      expect(args['android'], isNull);
      expect(args['name'], isNull);
    });

    test('asks nothing of a launcher that cannot add a widget', () async {
      // The plugin answers success and does nothing in that case, so a request
      // made anyway would read as a dialog that never opened.
      answer = (call) => false;

      expect(await store.requestPin(), isFalse);
      expect(calls.map((c) => c.method), isNot(contains('requestPinWidget')));
    });

    test('is false when the plugin refuses', () async {
      answer = (call) => call.method == 'isRequestPinWidgetSupported'
          ? true
          : throw PlatformException(code: '-4', message: 'ClassNotFound');

      expect(await store.requestPin(), isFalse);
    });
  });

  group('installedCount', () {
    test('counts the Cirrus widgets, however Android spells the class', () async {
      answer = (call) => [
        cirrus(11),
        cirrus(12),
        // The fully-qualified spelling, in case a future plugin sends it.
        {
          'widgetId': 13,
          'androidClassName': HomeWidgetStore.androidProvider,
          'label': 'Cirrus',
        },
      ];
      expect(await store.installedCount(), 3);
    });

    test('counts the iOS kind', () async {
      answer = (call) => [
        {'kind': HomeWidgetStore.iOSName, 'family': 'systemSmall'},
        {'kind': HomeWidgetStore.iOSName, 'family': 'accessoryCircular'},
      ];
      expect(await store.installedCount(), 2);
    });

    test('ignores a widget that is not ours', () async {
      answer = (call) => [
        {
          'widgetId': 5,
          'androidClassName': '.widget.SomethingElseProvider',
          'label': 'Other',
        },
        {'kind': 'NotCirrus', 'family': 'systemSmall'},
      ];
      expect(await store.installedCount(), 0);
    });

    test('is zero when none is placed', () async {
      answer = (call) => <Object?>[];
      expect(await store.installedCount(), 0);
    });

    test('is unknown, not zero, when the read fails', () async {
      // A broken read must never look like "nobody has it": the prompt would
      // then be offered to somebody who already does.
      answer = (call) => throw PlatformException(code: '-5');
      expect(await store.installedCount(), isNull);
    });
  });

  group('MemoryWidgetStore', () {
    test('is a device with no widget host until a test says otherwise', () async {
      // The fake backend runs on desktop and web, which have no launcher. Its
      // honest answer is "cannot add, count unknown" — which also keeps every
      // existing Home fixture free of a card it never asked for.
      final memory = MemoryWidgetStore();
      expect(await memory.canPin(), isFalse);
      expect(await memory.installedCount(), isNull);
      expect(await memory.requestPin(), isFalse);
      expect(memory.pinRequests, 0);
    });

    test('a launcher that can add records the request and counts the widget', () async {
      final memory = MemoryWidgetStore()
        ..pinSupported = true
        ..installed = 0;

      expect(await memory.canPin(), isTrue);
      expect(await memory.requestPin(), isTrue);
      expect(memory.pinRequests, 1);

      // The system dialog has no callback; the person confirming it is the
      // launcher placing the widget, which only a re-read can see.
      expect(await memory.installedCount(), 0);
      memory.placeWidget();
      expect(await memory.installedCount(), 1);
    });
  });
}
