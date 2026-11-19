import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the given client currently holds a signed-in Supabase session.
///
/// This answers "may this client present a user identity at all", not "is
/// this user an admin". It is used by the sync worker to decide whether the
/// publishable key alone (anonymous read) is enough or whether the user's own
/// access token should be attached.
bool hasSignedInSession(SupabaseClient client) {
  try {
    return client.auth.currentSession?.accessToken != null;
  } on AuthException {
    return false;
  }
}

/// Answers "is the signed-in user an administrator" for the UI.
///
/// The real boundary is PostgreSQL: the RLS policies on the four content
/// tables only accept writes where `app_metadata.role = 'admin'`, and that
/// claim sits outside anything the user can edit. This class exists so the
/// editor screens open for the same person the policies accept, instead of
/// trusting a copy of the role kept in memory since sign-in.
///
/// The check asks the Auth server (`getUser`) instead of reading
/// `currentUser`, because the local copy can be stale after a role change or
/// a revoked session. It reads `appMetadata` and never `userMetadata`, which
/// the account owner can write themselves.
///
/// Every failure (offline, no session, error response) answers `false`. The
/// admin UI is a convenience; a wrong answer here can only hide an editor,
/// never grant one.
class AdminGuard {
  const AdminGuard._();

  /// Verifies the session against the Auth server.
  static Future<bool> verify(SupabaseClient client) async {
    if (!hasSignedInSession(client)) return false;
    final user = await _serverUser(client);
    final metadata = user?.appMetadata;
    return metadata?['role'] == 'admin' ||
        metadata?['learn_law_role'] == 'admin';
  }

  /// Same question as [verify], but usable when the Auth server may be
  /// unreachable — on startup the app may still be showing an editor the
  /// session it restored from disk.
  ///
  /// The server's answer always wins. Only when no answer arrives (offline) is
  /// the restored session's own `app_metadata` used. That value came from a
  /// signed Auth response when the session was created, so it is still
  /// trustworthy for deciding what to render. It is never used to authorize a
  /// write: those go through RLS, which reads the row in `auth.users`.
  ///
  /// The refresh is attempted with [timeout] first. If that times out, a
  /// second short grace period reads whatever the refresh wrote into memory:
  /// a token that did resolve in the background lands there even after the
  /// caller stopped waiting for it.
  static Future<bool> verifyAllowingOffline(
    SupabaseClient client, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!hasSignedInSession(client)) return false;
    User? user;
    try {
      user = (await client.auth.getUser().timeout(timeout)).user;
    } catch (_) {
      user = null;
    }
    user ??= _restoredUser(client);
    final metadata = user?.appMetadata;
    return metadata?['role'] == 'admin' ||
        metadata?['learn_law_role'] == 'admin';
  }

  static Future<User?> _serverUser(SupabaseClient client) async {
    try {
      final refreshed = await client.auth.getUser().timeout(
        const Duration(seconds: 8),
      );
      return refreshed.user;
    } catch (_) {
      return null;
    }
  }

  static User? _restoredUser(SupabaseClient client) {
    try {
      return client.auth.currentUser;
    } on AuthException {
      return null;
    }
  }
}
