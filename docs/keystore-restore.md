# استعادة مفتاح توقيع التطبيق (Upload Keystore)

هذا الملف يُنسخ تلقائياً إلى مجلد النسخة الاحتياطية بجانب الملف المشفّر.

## ما الموجود في النسخة الاحتياطية

```
learnlaw-upload-key-<التاريخ>.enc          الملف المشفّر (AES-256)
learnlaw-upload-key-<التاريخ>.enc.sha256   بصمة الملف للتحقق من سلامته
RESTORE.md                                  هذا الملف
```

داخل الملف المشفّر:

```
android/upload-keystore.jks   مفتاح التوقيع
android/key.properties        كلمات المرور والـ alias
```

## اختيار التشفير

`AES-256-CBC` بمفتاح مشتق من كلمة المرور عبر `PBKDF2-HMAC-SHA256`
بـ 210,000 دورة و salt عشوائي لكل نسخة. الملف يبدأ بترويسة `LLK1` تحتوي:
salt (16 بايت)، IV (16 بايت)، ثم SHA-256 للنص الأصلي (للتحقق من سلامة الملف
بعد فك التشفير)، ثم النص المشفّر.

## خطوات الاستعادة

1. تحقّق من سلامة الملف قبل أي شيء (على Windows):

   ```powershell
   (Get-FileHash -Algorithm SHA256 learnlaw-upload-key-<التاريخ>.enc).Hash
   ```

   يجب أن يطابق المحتوى في ملف `.sha256`. إذا اختلفت البصمة، لا تستخدم
   الملف — استخدم النسخة الأخرى.

2. فك التشفير. الملف ليس أرشيفاً عادياً، فالمقصود فك تشفيره بـ PowerShell:

   ```powershell
   # اطلب كلمة المرور من مدير كلمات المرور عند هذه الخطوة
   $pass = Read-Host -AsSecureString 'Passphrase'
   ```

   ثم شغّل سكربت فك التشفير المرفق بالمشروع:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\restore_upload_keystore.ps1 `
     -Archive D:\backup\learnlaw-upload-key-<التاريخ>.enc -OutDir C:\restore
   ```

3. تحقّق من المفتاح قبل استخدامه:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_upload_keystore.ps1 `
     -Keystore C:\restore\android\upload-keystore.jks -KeyProperties C:\restore\android\key.properties
   ```

   البصمة الناتجة يجب أن تكون:
   `SHA-256: D5:25:D1:D1:A8:88:06:4E:E3:1B:57:1C:17:C2:D7:A0:BD:F6:0B:5F:87:8F:FB:72:03:31:2D:32:53:DB:12:3C`
   وقبل أول رفع، قارنها ببصمة «Upload key certificate» في
   Play Console → Setup → App signing. إن اختلفتا فالمفتاح المستخدم ليس
   المفتاح المسجّل لدى Google، ولا تُكمل الرفع.

4. أعِد الملفين إلى مكانهما:

   ```powershell
   Copy-Item C:\restore\android\upload-keystore.jks  <المشروع>\android\upload-keystore.jks
   Copy-Item C:\restore\android\key.properties      <المشروع>\android\key.properties
   ```

   بعدها احذف مجلد الاستعادة بالكامل، بما فيه النص غير المشفّر.

5. تحقّق من أن الملفين غير متتبّعين في Git:

   ```powershell
   git -C <المشروع> check-ignore -v android/key.properties android/upload-keystore.jks
   ```

6. ابنِ الحزمة مرة أخرى للتأكد:

   ```powershell
   flutter build appbundle --release
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_aab.ps1
   ```

## إذا ضاع المفتاح

لا يوجد مسار استعادة من Google Play لملف توقيع مفقود دون **Play App Signing**.
افحص أولاً في Play Console → Release → Setup → App signing ما إذا كان
«Upload key certificate» مطابقاً للبصمة أعلاه:

- **إذا كان المطابق هو مفتاح التوقيع الفعلي** (لم يُفعّل Play App Signing):
  استخدم «Upload key reset» في Play Console. يتطلب ذلك طلباً جديداً يمكن
  تسجيله بمفتاح جديد، وتوافق Google عليه.
- **إذا كان مفتاح App Signing من Google هو المفتاح الفعلي**: المفتاح المفقود
  هو مفتاح الرفع فقط، ويمكن استخدام «Upload key reset» لاستبداله دون أي
  تأثير على تثبيتات المستخدمين.

في الحالتين لا تُنشئ مفتاحاً جديداً وتستخدمه قبل موافقة Google على الطلب،
وإلا ستُرفض الحزمة برسالة عدم تطابق الشهادة.

## ما يجب ألّا تفعله

- لا تضع `key.properties` أو `.jks` في مستودع Git أو في أي خدمة سحابية
  غير مشفّرة.
- لا ترسل كلمة مرور النسخة الاحتياطية في نفس رسالة ملف `.enc`.
- لا تحتفظ بنسخة واحدة فقط، ولا في نفس قرص المشروع.
- لا تُنشئ مفتاحاً جديداً وتستبدل به الموجود: تحديثات التطبيق المستقبلية
  ستفشل.
