// Standalone production-callback regression. No Flutter SDK or package resolution.
// Run from repository root: dart tool/reader_system_ui_regression_test.dart
// Executes the unchanged _onRestoreComplete method in a narrow recording harness.
// Non-system-UI services are no-op adapters. This does NOT render Flutter, run
// Android, synthesize MediaQuery insets, or assert physical-screen symmetry.
import 'dart:io';

String extractMethod(String source, String signature) {
  final int start = source.indexOf(signature);
  if (start < 0) throw StateError('Missing production method: $signature');
  final int end = source.indexOf('\n  }\n', start);
  if (end < 0) throw StateError('Missing method boundary: $signature');
  return source.substring(start, end + 4);
}

Future<void> main() async {
  final Directory repo = File(Platform.script.toFilePath()).parent.parent;
  final String navigation = File(
    '${repo.path}/fushi/lib/src/pages/implementations/reader_fushi/navigation.part.dart',
  ).readAsStringSync();
  final String callback = extractMethod(
    navigation,
    '  void _onRestoreComplete() {',
  );
  final String app = File('${repo.path}/fushi/lib/src/models/app_model.dart')
      .readAsStringSync();
  // Use the production entrance request, not a hand-written replica. This is
  // an observation seam; the unrelated openMedia DB/navigation work is excluded.
  final String open = extractMethod(app, '  Future<void> openMedia({');
  final RegExp entrance = RegExp(
    r'await SystemChrome\.setEnabledSystemUIMode\(SystemUiMode\.[a-zA-Z]+\);',
  );
  final List<RegExpMatch> matches = entrance.allMatches(open).toList();
  if (matches.length != 1) throw StateError('Revisit openMedia system-UI seam');
  final File policyFile = File(
    '${repo.path}/fushi/lib/src/reader/reader_system_ui.dart',
  );
  final String policy = policyFile.existsSync()
      ? policyFile.readAsStringSync().replaceAll(
          "import 'package:flutter/services.dart';",
          '',
        )
      : '';
  final Directory temp = Directory.systemTemp.createTempSync(
    'fushi-reader-system-ui-',
  );
  try {
    final File generated = File('${temp.path}/production_callback.dart');
    generated.writeAsStringSync('''
import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Platform;
class Platform { static bool isAndroid = true; }
enum SystemUiMode { immersiveSticky, edgeToEdge, immersive, leanBack, manual }
class SystemChrome {
  static final List<SystemUiMode> calls = [];
  static Future<void> setEnabledSystemUIMode(SystemUiMode mode) async { calls.add(mode); }
}
$policy
class ReaderChapterPerfTrace { static void mark(String s) {} static void end() {} }
class Trace { void mark(String s) {} void report() {} }
enum FocusReclaimCause { contentReady }
class FocusOwner { void reclaim(FocusReclaimCause cause) {} }
class WidgetsBinding {
  static final WidgetsBinding instance = WidgetsBinding();
  final List<void Function(Object?)> frames = [];
  void addPostFrameCallback(void Function(Object?) callback) { frames.add(callback); }
  void flush() { final callbacks = List.of(frames); frames.clear(); for (final callback in callbacks) { callback(null); } }
}
class AudiobookBridge { static void resetImagePauseAnchor(Object controller) {} }
class Audio { void notifySectionRestoreCompleted({required int currentReaderSection, required bool success}) {} }
void debugPrint(String value) {}
class Harness {
  bool _popInProgress = false;
  bool mounted = true, _restoreInFlight = true, _readerContentReady = false, _hasEverLoaded = false;
  Completer<bool>? _restoreCompleter;
  double _lastSyncedWidth = 0, _lastSyncedHeight = 0, _paginatedWidth = 400, _paginatedHeight = 824;
  final Trace _openTrace = Trace();
  final FocusOwner _focusOwnership = FocusOwner();
  Audio? _audiobookController;
  ({bool isContinuousMode, bool isVnMode, bool tapEmptyToHideChrome})? _settings;
  bool get _bottomBarFloating => _settings?.tapEmptyToHideChrome ?? true;
  int _currentChapter = 0, _navigateGeneration = 0, _chapterAdvanceDirection = 1;
  Object? _controller;
  void _clearContentReadyTimeout() {}
  void _rebuild(void Function() action) { action(); }
  void _reapplyChromeInsetsAfterFirstLoad() {}
  void _syncPageSize() {}
  void _ensureStudyClock() {}
  void _reanchorContinuousAfterRestore() {}
  Future<void> _applyPendingPreciseLocate() async {}
  void _applyChapterHighlights() {}
  void _refreshProgress() {}
  void _startProgressPoll() {}
  void _diag718ProbeViewportDrift() {}
  void _prefetchAdjacentChapterImages(int chapter) {}
  Future<void> _replayPendingPageTurn() async {}
$callback
}
Future<void> main() async {
  int failures = 0;
  for (final bool android in [true, false]) {
  Platform.isAndroid = android;
  for (final String scenario in ['first paginated load', 'first continuous load', 'first VN load', 'chapter load', 'closing route', 'already ready', 'disposed']) {
    SystemChrome.calls.clear();
    WidgetsBinding.instance.frames.clear();
    ${matches.single.group(0)}
    final Harness page = Harness();
    page._settings = (isContinuousMode: scenario.contains('continuous'), isVnMode: scenario.contains('VN'), tapEmptyToHideChrome: true);
    if (scenario == 'chapter load') { page._hasEverLoaded = true; page._currentChapter = 2; }
    if (scenario == 'already ready') { page._readerContentReady = true; page._hasEverLoaded = true; }
    if (scenario == 'disposed') page.mounted = false;
    if (scenario == 'closing route') {
      page._popInProgress = true;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    final int beforeRestoreCalls = SystemChrome.calls.length;
    page._onRestoreComplete();
    WidgetsBinding.instance.flush();
    await Future<void>.delayed(Duration.zero);
    // Contract: a content-ready callback must not undo the reader's entrance
    // immersive request. On Flutter 3.47.6 Android, edgeToEdge clears the hidden
    // system-bar flags. We assert that hazardous request, NOT invented pixels.
    final bool entranceIsImmersive = SystemChrome.calls.isNotEmpty && SystemChrome.calls.first == SystemUiMode.immersiveSticky;
    final bool restored = !page.mounted || (page._readerContentReady && page._hasEverLoaded && !page._restoreInFlight);
    if (!entranceIsImmersive) throw StateError('Production entrance is no longer immersive; revisit the contract');
    if (!restored) throw StateError('Production callback did not finish restoration');
    final bool contentReadyRequest = page.mounted && scenario != 'already ready';
    final bool pass = scenario == 'closing route'
        ? SystemChrome.calls.length == beforeRestoreCalls
        : android
            ? !SystemChrome.calls.skip(1).contains(SystemUiMode.edgeToEdge)
            : (!contentReadyRequest || SystemChrome.calls.last == SystemUiMode.edgeToEdge);
    if (!pass) failures++;
    print(jsonEncode({'android': android, 'scenario': scenario, 'pass': pass, 'modes': SystemChrome.calls.map((m) => m.name).toList()}));
  }
  }
  if (failures > 0) { stderr.writeln('FAIL: \$failures reader-ready callbacks violate the platform system-UI policy'); exitCode = 1; }
}
''');
    final ProcessResult result = await Process.run(
      Platform.resolvedExecutable,
      [generated.path],
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  } finally {
    temp.deleteSync(recursive: true);
  }
}
