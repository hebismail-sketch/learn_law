import 'package:flutter/foundation.dart';

/// Central logger for the app.
///
/// In release builds Flutter's `debugPrint` is compiled down to a no-op, but
/// any `print` call that slips into the code would still reach logcat, where
/// another app with READ_LOGS (or a connected debugger) could read it. Routing
/// every diagnostic through this class keeps that guarantee in one place:
/// callers pass a short, secret-free message, and nothing here ever logs a
/// request body, a token or a user record.
///
/// [error] is only written in debug builds. In release the message alone is
/// enough to see that something failed without exposing a stack trace or a
/// response body to the device log.
void logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

void logError(String message, [Object? error]) {
  if (!kDebugMode) return;
  if (error == null) {
    debugPrint(message);
  } else {
    debugPrint('$message: $error');
  }
}
