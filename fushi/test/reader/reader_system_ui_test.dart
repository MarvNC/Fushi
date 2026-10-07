import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fushi/src/reader/reader_system_ui.dart';

import '../helpers/source_guard.dart';

/// BUG-3065: verify the real SystemChrome platform-channel requests. These
/// tests do not simulate Android's WindowInsets or measure physical margins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'Android content readiness preserves the entrance immersive policy',
    () async {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await setReaderContentReadySystemUiMode(isAndroid: true);
      expect(
        calls.map((MethodCall call) => call.method),
        everyElement('SystemChrome.setEnabledSystemUIMode'),
      );
      expect(calls.map((MethodCall call) => call.arguments), <String>[
        SystemUiMode.immersiveSticky.toString(),
        SystemUiMode.immersiveSticky.toString(),
      ]);
    },
  );

  test('Android repeated chapters never request edge-to-edge', () async {
    for (int chapter = 0; chapter < 3; chapter++) {
      await setReaderContentReadySystemUiMode(isAndroid: true);
    }
    expect(calls, hasLength(3));
    expect(
      calls.map((MethodCall call) => call.arguments),
      everyElement(SystemUiMode.immersiveSticky.toString()),
    );
  });

  test(
    'non-Android retains its existing edge-to-edge readiness policy',
    () async {
      await setReaderContentReadySystemUiMode(isAndroid: false);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.single.arguments, SystemUiMode.edgeToEdge.toString());
    },
  );

  test(
    'production readiness callback preserves the policy across states',
    () async {
      // The Flutter launcher exports FLUTTER_ROOT before starting the tester.
      // Isolate.resolvePackageUri is unsupported inside flutter_tester.
      final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
      expect(flutterRoot, isNotNull);
      final String dartName = Platform.isWindows ? 'dart.exe' : 'dart';
      final File dart = File('$flutterRoot/bin/cache/dart-sdk/bin/$dartName');
      expect(
        dart.existsSync(),
        isTrue,
        reason: 'Dart SDK beside the running Flutter SDK',
      );
      final ProcessResult result = await Process.run(dart.path, <String>[
        '../tool/reader_system_ui_regression_test.dart',
      ]);
      expect(
        result.exitCode,
        0,
        reason:
            'Production callback failed:\n${result.stdout}\n${result.stderr}',
      );
      expect('"pass":true'.allMatches(result.stdout as String), hasLength(14));
    },
  );

  test(
    'ready callback uses the runtime platform through the tested policy',
    () {
      final String navigation = File(
        'lib/src/pages/implementations/reader_fushi/navigation.part.dart',
      ).readAsStringSync();
      final String body = methodBody(navigation, 'void _onRestoreComplete() {');
      expect(
        body,
        contains(
          'setReaderContentReadySystemUiMode(isAndroid: Platform.isAndroid)',
        ),
      );
      expect(body, isNot(contains('SystemChrome.setEnabledSystemUIMode')));
    },
  );
}
