import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a Supabase Auth failure into a message that is safe to show.
///
/// Two rules:
///
///   * never render `AuthException.toString()` or the raw response, which can
///     carry the project URL, a request id, or the server's own wording;
///   * keep the message generic about credentials, so it does not tell an
///     attacker whether an email exists.
///
/// The sign-in form already shows the same text for "wrong password" and
/// "no such user"; this class only distinguishes causes the user can act on
/// (network, rate limit, unconfirmed email, MFA).
abstract final class AuthErrorText {
  static String forException(AuthException error) {
    final code = error.code?.toLowerCase();
    final message = error.message.toLowerCase();

    if (error is AuthRetryableFetchException ||
        code == 'network_error' ||
        message.contains('socket') ||
        message.contains('failed host lookup')) {
      return 'تعذّر الاتصال بالخادم. تحقّق من الشبكة وحاول مجددًا.';
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit') {
      return 'محاولات كثيرة. انتظر دقيقة ثم حاول مجددًا.';
    }
    if (code == 'email_not_confirmed') {
      return 'يلزم تأكيد البريد الإلكتروني لهذا الحساب قبل الدخول.';
    }
    if (code == 'invalid_credentials') {
      return 'بيانات الدخول غير صحيحة.';
    }
    if (code == 'mfa_challenge_expired' || code == 'mfa_verification_failed') {
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته.';
    }
    if (message.contains('too many requests')) {
      return 'محاولات كثيرة. انتظر دقيقة ثم حاول مجددًا.';
    }
    if (message.contains('invalid login credentials')) {
      return 'بيانات الدخول غير صحيحة.';
    }
    return 'تعذّر إتمام العملية. تحقّق من بياناتك وحاول مجددًا.';
  }
}
