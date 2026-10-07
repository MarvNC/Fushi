import 'package:flutter/services.dart';

/// Applies the reader's system-UI policy after a chapter becomes ready.
///
/// Android entered immersiveSticky in AppModel.openMedia. Flutter 3.47 now
/// clears hidden-system-bar flags when switching to edgeToEdge, so that old
/// restore-time request exposed the status bar and shifted the book down.
/// Explicitly retain immersion on Android. Other platforms keep the previous
/// edgeToEdge policy. Real cutout/safe-area insets remain owned by the reader.
///
/// The caller supplies the runtime platform so the platform-channel contract
/// can be tested on a host runner without substituting SystemChrome itself.
Future<void> setReaderContentReadySystemUiMode({required bool isAndroid}) =>
    SystemChrome.setEnabledSystemUIMode(
      isAndroid ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
