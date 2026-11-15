# Google Play — Closed Testing Submission Checklist (Learn Law / مِراس)

Status of the build this checklist refers to (verified 2026-11-15):

| Item | Value |
|---|---|
| Package name | `com.learnlaw.app` |
| Version name / code | `1.0.0` / `1` |
| minSdk / targetSdk | 24 / 36 |
| Bundle | `build/app/outputs/bundle/release/app-release.aab` (69.1 MB) |
| Signature | `CN=Miras, OU=Mobile, O=Miras, L=Cairo, ST=Cairo, C=EG`, SHA256withRSA 2048 |
| Certificate SHA-256 | `D5:25:D1:D1:A8:88:06:4E:E3:1B:57:1C:17:C2:D7:A0:BD:F6:0B:5F:87:8F:FB:72:03:31:2D:32:53:DB:12:3C` |
| Native libs | arm64-v8a, armeabi-v7a, x86_64 — uncompressed, 16 KB aligned |

Everything in **Part A** is done in the code. **Part B** must be entered by hand
in Play Console; the text to paste is provided. **Part C** lists what the
reviewer must be able to do and what to type into App Access.

---

## Part A — prepared in the repository

- [x] Target SDK 36 (Play requires 35+ for new apps since 2025-08-31).
- [x] Release signing from `android/app/upload-keystore.jks` (not the debug key);
      fingerprint verified by `scripts/verify_upload_keystore.ps1`.
- [x] `android:allowBackup="false"`, `android:fullBackupContent="false"` and
      `android:dataExtractionRules="@xml/data_extraction_rules"` — the session
      and the local cache are excluded from cloud backup and device transfer.
- [x] No `android:debuggable` in the release manifest; `isDebuggable = false`
      set explicitly.
- [x] Only two normal permissions in the merged manifest
      (`INTERNET`, `ACCESS_NETWORK_STATE`) plus the four AdMob permission
      entries the SDK adds. Nothing that needs a Play permissions declaration
      form (no location, camera, SMS, contacts, storage).
- [x] No exported components besides the launcher activity; every AdMob,
      WorkManager, URL-launcher and startup component is `exported="false"`
      (the one exception, `SystemJobService`, is protected by
      `BIND_JOB_SERVICE`).
- [x] No deep links / App Links declared, so no link verification is needed.
- [x] AAB builds without errors; `jarsigner -verify` reports `jar verified`.
- [x] 67 unit/widget tests pass, `flutter analyze` clean.
- [x] Keystore and `key.properties` are git-ignored and untracked.

## Part B — manual entry in Play Console

### B1. App content → Privacy policy

Required because the app shows ads. Publish a page first; it must be reachable
without login. Suggested content (Arabic + English summary):

```
تطبيق «مِراس» تطبيق تعليمي لمهارات المحاماة. لا يطلب من المستخدم إنشاء حساب
للاستخدام العادي، ولا يجمع اسمه أو رقم هاتفه أو بريده الإلكتروني.

ما يُخزَّن على الجهاز: نسخة محلية من المحتوى القانوني التعليمي، وإعدادات المظهر
والمفضلة، ورمز جلسة محلية (إن سجّل المشرف الدخول) داخل التخزين الآمن للنظام.
لا تُرسل هذه البيانات إلى جهة غير Supabase.

الإعلانات: يعرض التطبيق إعلانات Google AdMob. قد تجمع Google والشركات الشريكة
معرّف الإعلان وبيانات الاستخدام لعرض إعلانات أكثر ملاءمة، وفق سياسات Google.
يمكنك التحكم في الإعلانات المخصصة من إعدادات Google.

الأطفال: التطبيق غير موجّه للأطفال دون 13 عاماً (التصنيف العمري: 13+).

الحقوق: المحتوى تعليمي عام ولا يُعد استشارة قانونية. القوانين تتغير؛ راجع
المصادر الرسمية قبل الاعتماد على أي إجراء.

للتواصل: <ضع بريدك هنا>
آخر تحديث: <التاريخ>
```

### B2. App content → Data safety

Answers consistent with the code in this repository:

| Question | Answer |
|---|---|
| Does your app collect or share any required user data types? | **Yes** (advertising identifier, used by AdMob) |
| Data type | Device or other IDs → **Advertising ID** |
| Collected or shared | **Shared** with Google (AdMob) |
| Purposes | Advertising or marketing; (optionally) App functionality |
| Is the data encrypted in transit? | Yes (HTTPS / TLS) |
| Can users request data deletion? | **No account is created for readers**, so there is no account data to delete. Admins can request deletion of the admin account by email. |
| Is any collected data optional? | No |
| Data collected by the app itself (content sync, favourites) | Not collected — stored on device, public content |

Important: **do not** declare "App activity" for the reader path; the app does
not send reading history anywhere. The only network calls are the content pull
(public tables) and the ad SDK.

### B3. App access

The reader path works with no sign-in, but the admin area is hidden. Give the
reviewer a way in **only if you want the admin area reviewed**; otherwise state:

> All features are available without signing in. There is no login screen in
> the main flow. The administration area is for the content owner only and is
> not part of the user-facing experience.

If you want it reviewed, create a **separate non-production admin test account**
in the review Supabase project (never the production admin), and then enter:

| Field | Value to enter |
|---|---|
| Type | Username and password |
| Name | Content editor (review build) |
| Username/email | *(the review account email you create)* |
| Password | *(its password)* |
| Instructions | Open the app → Home → tap the app title **10 times quickly** → "بوابة تسجيل دخول المشرف" → enter the credentials above. |

Do not paste the production admin credentials here.

### B4. Ads

- [x] App contains ads → **Yes**.
- [x] Ads are shown: an interstitial between content navigation (rate-limited)
      and a banner on browsing screens.
- Current build uses Google's **sample AdMob IDs** on purpose, so the closed
  test shows test inventory and earns nothing. Before going public, replace the
  app ID and unit IDs with your own (see Part C2).

### B5. Content rating (IARC questionnaire)

Suggested answers for this app:

- Category: **Reference, News or Educational** → Educational.
- Violence, sexuality, profanity, drugs, gambling: **No**.
- Users can interact / share content: **No**.
- Shares location: **No**.
- Digital purchases: **No**.
- Contains ads: **Yes**.
- Expected result: **Everyone / 3+**. If IARC returns a lower age because of
  ads, that is fine; the app content is legal education, not legal advice.

### B6. Target audience

- Age groups: **13–15, 16–17, 18+**. Do **not** select under-13: the app shows
  ads and is not designed for a child audience.
- "Designed for families": **No**.

### B7. Store listing assets

| Asset | Requirement | Status |
|---|---|---|
| App name | ≤ 30 chars | suggest: `مِراس — تدريب المحامي` |
| Short description | ≤ 80 chars | prepared below |
| Full description | ≤ 4000 chars | prepared below |
| App icon | 512×512 PNG, no transparency | **needs export from `android/app/src/main/res/mipmap-*`** |
| Feature graphic | 1024×500 | **needs artwork** |
| Phone screenshots | ≥ 2, 16:9 or 9:16 | **needs capture on a device** |
| Data safety, privacy policy URL | from B1 | **needs the URL** |

Short description (78 chars):

```
منصة تدريب قانوني عربي: قضايا، خطوات إجرائية، ومسارات تفاعلية للمحامي
```

Full description draft:

```
«مِراس — تدريب المحامي» تطبيق تعليمي لطلاب القانون والمحامين الجدد.
يبني مهارات التعامل مع القضايا خطوة بخطوة: تصنيفات قانونية، قضايا واقعية،
وخطوات إجرائية مرتبة مع ملاحظات عملية.

ما يقدمه التطبيق:
• مكتبة قضايا مرتبة تحت تصنيفات وأقسام واضحة.
• لكل قضية مسار مراحل يعرض ما يجب فعله وما يجب تجنبه.
• بحث شامل، ومفضلة سريعة، ووضعين للاطلاع: فاتح وداكن.
• يعمل دون اتصال بعد أول تحميل، وتتحدث البيانات تلقائياً عند عودة الشبكة.

تنبيه: المحتوى تعليمي عام، ولا يُعد استشارة قانونية أو استشارة خاصة لقضية
معينة. اطلع دائماً على النصوص الرسمية النافذة قبل اتخاذ أي إجراء.

يُعرض في التطبيق إعلان محدود عبر Google AdMob.
```

### B8. Closed testing requirements (developer account type)

- Personal accounts created after Nov 2023 need **12 testers for 14 days**
  before applying for production. Prepare a tester list or a Google Group.
- Upload the AAB to **Testing → Closed testing → Create track → Upload**.
- Add release notes: `النسخة الأولى للاختبار المغلق.`

## Part C — remaining engineering actions (not part of the closed test)

### C1. AdMob placeholders → real IDs

The build currently ships Google's sample app id
(`ca-app-pub-3940256099942544~3347511713`) in `AndroidManifest.xml` and test
unit ids in `lib/core/ads/ad_mob_service.dart`. Replace both when going public.
Playing with production ads before that is a policy violation.

### C2. Session hardening before public release

`supabase_flutter` stores the session in SharedPreferences, not the Android
Keystore. The admin session is therefore readable on a rooted device.
Recommended fix (requires adding `flutter_secure_storage`): implement
`LocalStorage` from `supabase_flutter` on top of it and pass it to
`Supabase.initialize(localStorage: ...)`. Test on Android 9 and 14 after the
change. Until then the exposure is limited to one admin account with a
server-side role check on every write.

### C3. Play App Signing

Enable **Play App Signing** before the first production upload. Google then holds
the app signing key and the keystore in `android/app/upload-keystore.jks` stays
the *upload* key — which is the recoverable case. Compare the fingerprints in
Play Console → Setup → App signing with the one at the top of this file.
