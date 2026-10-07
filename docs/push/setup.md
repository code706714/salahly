# إشعارات "قربت أوصل" (Push): خطوات التشغيل

الكود جاهز. اللي ناقص حاجات لازم تعملها إنت من حسابك لأن فيها مفاتيح سرية
(مفيش أي مفتاح اتحط في الريبو). من غير الخطوات دي الأبلكيشن بيشتغل عادي،
بس الإشعار مش بيوصل لموبايل العميل وهو قافل الأبلكيشن. الفني لسه بيشوف زرار
"قربت أوصل" والعميل بيشوف الخبر في قائمة الإشعارات وفي صفحة المتابعة.

## الفكرة في سطرين

1. الفني يدوس "قربت أوصل" فيتسجّل إشعار للعميل في قاعدة البيانات
   (`technician_arriving`).
2. قاعدة البيانات بتنده على الدالة `send-push` أول ما يتسجّل إشعار يستاهل،
   وكل دقيقة كإعادة محاولة لو فيه إشعارات مستنية. الدالة بتبعتها لموبايل العميل
   عن طريق Firebase (FCM). الإشعار فيه اسم الفني الأول ونوع الخبر بس. مفيش رقم
   ولا عنوان.

## الخطوات

### 1) مشروع Firebase
1. ادخل https://console.firebase.google.com واعمل مشروع جديد (من غير Analytics).
2. Add app, Android. اكتب الـ package name:
   - `com.salahly.app` (الإنتاج)
   - وكرّر لـ `com.salahly.app.staging` و `com.salahly.app.dev` لو عايز تجرّب
     على النسخ دي.
3. نزّل `google-services.json` وحطه في `android/app/google-services.json`
   (لو ضفت أكتر من أبلكيشن، نفس الملف بيشملهم كلهم). الملف ده
   **متجاهَل في git** (`.gitignore`) فمتحاولش ترفعه.
   لو عايز ملف لكل نسخة: `android/app/src/dev/` و `staging` و `prod`.
4. من غير الملف ده البناء بيشتغل عادي والإشعارات متقفلة. أول ما تحطه
   وتبني تاني الإشعارات بتشتغل، من غير تغيير في الكود.

### 2) مفتاح الإرسال (Service account)
1. Firebase Console, Project settings, Service accounts, Generate new private key.
   هينزل ملف JSON. ده سرّي جداً.
2. الـ service account لازم يكون عنده دور **Firebase Cloud Messaging API Admin**
   (الحساب الافتراضي `firebase-adminsdk` عنده كفاية).
3. خزّنه في Supabase (محتوى الملف كله):

   ```
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
   ```
   وبعدين امسح الملف من جهازك.

### 3) كلمة السر بين قاعدة البيانات والدالة
اختار نص عشوائي طويل (32 حرف على الأقل) واستخدمه في مكانين:

```
supabase secrets set PUSH_SECRET=<النص>
supabase functions deploy send-push --no-verify-jwt
```

وفي الـ SQL editor في Supabase:

```sql
select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/send-push', 'push_dispatch_url');
select vault.create_secret('<نفس النص>', 'push_dispatch_secret');
```

لو الاتنين مش موجودين قاعدة البيانات مش بتبعت حاجة وبتكتب تحذير في اللوج
(`push is not configured`). مفيش حاجة بتبوظ.

### 4) الـ migration
`supabase db push` (الملف `20261008090000_push_notifications.sql`). بيستخدم
`pg_net` و `pg_cron` وهما موجودين أصلاً من الـ purge.

### 5) جرّب
1. ثبّت النسخة على موبايلين: واحد عميل وواحد فني. اقبل إذن الإشعارات (بيظهر
   بعد رسالة بالعربي بتشرح السبب).
2. اعمل طلب، واختار الفني، وأكّد. الفني يفتح الشغلانة ويدوس "قربت أوصل".
3. قفل أبلكيشن العميل. المفروض يجيله إشعار خلال دقيقة تقريباً. الدوس عليه يفتح الطلب.
4. لو مجاش:
   - `select count(*), min(queued_at) from private.push_outbox;` الصف بيتمسح
     أول ما يتبعت. لو لسه موجود يبقى لسه ما اتبعتش.
   - `select private.push_backlog();` عمر أقدم إشعار مستني. نبّه لو عدى ساعة.
   - Supabase, Edge Functions, send-push, Logs. (الدالة مش بتكتب التوكن ولا الأرقام في اللوج.)
   - 503 معناه إن `FCM_SERVICE_ACCOUNT_JSON` ناقص. 401 معناه إن `PUSH_SECRET`
     مش زي `push_dispatch_secret`.
   - العميل لازم يكون سجّل الدخول وقبل الإذن على الموبايل ده مرة على الأقل.

## اللي لازم تعرفه
- **iOS مش متظبط.** محتاج Apple Developer account ومفتاح APNs في Firebase
  و `GoogleService-Info.plist`. التطبيق دلوقتي بيشغّل الإشعارات على أندرويد بس.
- التوكن بيتمسح لما المستخدم يخرج من حسابه، ولما يمسح الحساب، ولما الموبايل
  ما يستخدمش الأبلكيشن 60 يوم، ولما Firebase يقول إنه مبقاش صالح.
- أقصى 5 موبايلات لكل حساب. الفني يقدر يدوس "قربت أوصل" 3 مرات في الطلب،
  والدوسة التانية خلال 10 دقايق ما بتبعتش إشعار جديد.
- الإشعارات اللي عدّى عليها أكتر من ساعة بتتساب ومبتتبعتش.
- الحساب الموقوف مبتوصلوش إشعارات.
- Play Console: راجع `docs/release/data-safety.md` (صف الـ device ID اتحدّث).
