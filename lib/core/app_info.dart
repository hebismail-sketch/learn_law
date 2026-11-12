import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Public contact address shown in the in-app legal notice.
///
/// It must match the contact email on the Google Play store listing and the
/// privacy policy page. Override it at build time with
/// `--dart-define=SUPPORT_EMAIL=you@example.com`.
const supportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'esmailheba31@gmail.com',
);

/// Opens the legal notice / disclaimer screen.
Future<void> openLegalNotice(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const LegalNoticeScreen()),
  );
}

/// Explains what the app is, that it is not legal advice, and how to reach the
/// developer. Google Play requires this kind of disclosure for apps that give
/// legal information, and it is also the in-app entry point to the privacy
/// policy.
class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'طبيعة التطبيق',
      '«مِراس | تدريب المحامي» تطبيق تعليمي وتدريبي يعرض الإجراءات القانونية '
          'في صورة خطوات ومسارات، لمساعدة المحامين والمتدربين وطلاب الحقوق '
          'والمواطنين على فهم تسلسل الإجراءات.',
    ),
    (
      'ليس استشارة قانونية',
      'المحتوى المنشور داخل التطبيق لأغراض تعليمية وإرشادية فقط، ولا يُعد '
          'استشارة قانونية ولا بديلاً عن مراجعة محامٍ مرخّص أو الاطلاع على '
          'النصوص القانونية السارية. قد تختلف الإجراءات بحسب الوقائع والجهة '
          'المختصة والتعديلات التشريعية.',
    ),
    (
      'دقة المحتوى',
      'نحرص على مراجعة المحتوى وتحديثه، لكننا لا نضمن خلوّه من الأخطاء أو '
          'ملاءمته لكل حالة بعينها، ولا نتحمل مسؤولية أي قرار يُتخذ اعتماداً '
          'عليه دون الرجوع إلى مختص.',
    ),
    (
      'الخصوصية والبيانات',
      'لا يطلب التطبيق إنشاء حساب لاستخدامه، ولا يجمع بيانات شخصية. تُحفظ '
          'المفضلة وإعدادات المظهر على جهازك فقط. يستخدم التطبيق إعلانات '
          'Google AdMob التي قد تعالج معرّفات الجهاز والإعلان وفق سياسات '
          'Google، ويمكنك مراجعة تفاصيل ذلك في سياسة الخصوصية المنشورة على '
          'صفحة التطبيق في Google Play.',
    ),
    (
      'الإعلانات',
      'التطبيق مجاني ومدعوم بالإعلانات، وجميع المحتوى متاح دون أي مقابل أو '
          'مشاهدة إعلان. تظهر إعلانات Google AdMob في صورة إعلان افتتاحي عند '
          'بدء التشغيل، ولافتة أسفل بعض الشاشات، وإعلان بيني عند التنقل بين '
          'الصفحات.',
    ),
    (
      'التواصل',
      'لأي استفسار أو ملاحظة أو الإبلاغ عن خطأ في المحتوى، راسلنا على:',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return rebuildWithAppTheme(
      (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'إخلاء المسؤولية وسياسة الخصوصية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          centerTitle: true,
          actions: const [ThemeToggleButton()],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (title, body) in _sections) ...[
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    SelectableText(
                      supportEmail,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
