import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const reviewSessionStorageKey = 'learn_law_review_supabase_session';

class ReviewSessionStore {
  ReviewSessionStore({required this.client, required this.storage});

  final SupabaseClient client;
  final SharedPreferencesLocalStorage storage;
  StreamSubscription<AuthState>? _subscription;

  Future<void> initialize() async {
    await storage.initialize();
    final persistedSession = await storage.accessToken();
    if (persistedSession != null) {
      try {
        await client.auth.recoverSession(persistedSession);
      } on AuthException catch (error, stackTrace) {
        await storage.removePersistedSession();
        debugPrint('Review session could not be restored: $error\n$stackTrace');
      }
    }

    _subscription = client.auth.onAuthStateChange.listen(
      (state) => unawaited(_persist(state)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Review auth state stream failed: $error\n$stackTrace');
      },
    );
  }

  Future<void> _persist(AuthState state) async {
    try {
      if (state.event == AuthChangeEvent.signedOut) {
        await storage.removePersistedSession();
      } else if (state.session != null) {
        await storage.persistSession(jsonEncode(state.session!.toJson()));
      }
    } catch (error, stackTrace) {
      debugPrint('Could not persist review session: $error\n$stackTrace');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
