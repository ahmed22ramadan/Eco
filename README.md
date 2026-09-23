# إيكو (Eco)

تطبيق Flutter متصل بـ Firebase. النسخة الحالية فيها:
- تسجيل الدخول/إنشاء حساب (إيميل وباسورد + Google)
- شاشة رئيسية بقائمة "طلباتي" (متصلة بـ Firestore فعليًا)
- شاشة طلب تحصيل جديد بأربع خطوات (الفئة والكمية، العنوان والموبايل والخريطة، الميعاد، الصورة والملاحظات) — بتحفظ الطلب في Firestore وترفع الصورة على Firebase Storage

## ملاحظة مهمة
المشروع ده متبني بحيث GitHub Actions هو اللي "يخلق" مجلد الأندرويد ويبني الـ APK تلقائيًا — مش محتاج تنزّل Flutter ولا Android Studio على جهازك خالص عشان تجيب الـ APK.

---

## الخطوات قبل أول تشغيل

### 1. جهّز مشروع Firebase
- ادخل [Firebase Console](https://console.firebase.google.com) على نفس المشروع اللي عملته.
- من "Project settings" ضيف تطبيق أندرويد جديد، واستخدم بالظبط اسم الحزمة ده:
  ```
  com.robabikya.app
  ```
- حمّل ملف `google-services.json` اللي هيظهرلك، واستبدل بيه الملف الموجود في جذر المشروع (اللي فيه بيانات وهمية حاليًا).

### 2. فعّل طرق الدخول
من قسم **Authentication → Sign-in method** في Firebase، فعّل:
- Email/Password
- Google

### 3. لازم لدخول Google تحديدًا: أضف بصمة SHA-1
تسجيل الدخول بجوجل مش هيشتغل من غيرها. على جهازك، شغّل:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

(لو مش عندك `~/.android/debug.keystore`، شغّل أي أمر `flutter build` أو `flutter run` مرة واحدة الأول عشان يتولّد تلقائي، أو ثبّت Android Studio اللي بيعمله تلقائي.)

انسخ قيمة **SHA1** اللي هتظهر، وضيفها في Firebase Console: **Project settings → معلومات التطبيق (Android) → Add fingerprint**.

### 4. جهّز Firestore (لتخزين الطلبات)
من **Firestore Database** في Firebase، اعمل "Create database" (اختار "Start in test mode" مبدئيًا).

غيّر قواعد Firestore (تبويب Rules) بالنسخة دي — بتسمح لكل عميل يشوف طلباته هو بس، وتديك أنت (كأدمن) صلاحية تشوف وتعدّل كل الطلبات:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null &&
             exists(/databases/$(database)/documents/admins/$(request.auth.token.email));
    }

    match /orders/{orderId} {
      allow read: if request.auth != null &&
                     (request.auth.uid == resource.data.userId || isAdmin());
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      allow update: if isAdmin();
      allow delete: if isAdmin();
    }

    match /settings/{docId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    match /admins/{adminEmail} {
      allow read: if request.auth != null && request.auth.token.email == adminEmail;
      allow write: if false;
    }
  }
}
```

### 5. فعّل نفسك كأدمن (عشان تشوف لوحة متابعة الطلبات)
1. من **Firestore Database → Data** في Firebase Console، اعمل collection جديدة اسمها بالظبط `admins`.
2. جوه الـ collection دي، اعمل document جديد، وخلي الـ **Document ID** هو نفس الإيميل اللي بتسجل بيه دخول في التطبيق بالظبط (بحروف صغيرة).
3. أي حقل جواه مش مهم (سيبه فاضي أو حط حقل تجريبي زي `role: "admin"`)، المهم وجود الـ document نفسه.
4. اقفل التطبيق وافتحه تاني (أو اعمل تسجيل خروج ودخول)، هيظهرلك زرار جديد فوق في شاشة الرئيسية يوديك للوحة متابعة كل الطلبات.

### 6. أول مرة تفتح صفحة "طلباتي"
لو ظهرلك خطأ نصه بيتكلم عن "index" جوه التطبيق، ده طبيعي أول مرة — Firestore بيحتاج فهرس (index) عشان يرتب الطلبات. الخطأ نفسه بيجيب معاه رابط، افتحه في المتصفح ودوس "Create Index"، واستنى دقيقة أو اتنين، وبعدها هيشتغل عادي.

---

## إزاي تجيب الـ APK (مجانًا بالكامل)

1. اعمل حساب/repo جديد على [GitHub](https://github.com) لو معندكش.
2. من مجلد المشروع، شغّل:
   ```bash
   git init
   git add .
   git commit -m "أول نسخة من إيكو"
   git branch -M main
   git remote add origin https://github.com/USERNAME/robabikya.git
   git push -u origin main
   ```
3. روح لتبويب **Actions** في الـ repo بتاعك على GitHub، هتلاقي "Build APK" شغالة تلقائيًا (بتاخد حوالي 5-10 دقايق أول مرة).
4. لما تخلص، دوس عليها، وهتلاقي في الأسفل ملف باسم **robabikya-apk** — حمّله (هيجيلك كـ zip فيه الـ APK جواه).
5. فك الضغط، وابعت ملف `app-release.apk` لموبايل أندرويد (واتساب/درايف/كابل)، وثبّته (لازم تفعّل "السماح بتثبيت من مصادر غير معروفة" من إعدادات الموبايل).

---

## لو البناء فشل على GitHub Actions
ابعتلي رسالة الخطأ اللي هتظهر في الـ Actions log، وهساعدك تصلّحها فورًا. أشهر مشكلة محتملة: لو ظهر خطأ متعلق بـ `minSdkVersion`، افتح `android/app/build.gradle` (بعد ما يتولّد) وغيّر السطر الخاص بيه لـ `minSdk 23`.

## ملاحظات تصميم
- لسه مفيش أيقونة Google الرسمية على زرار "الدخول بحساب Google" — استخدمت أيقونة عامة بديلة مؤقتًا. لو عايز الشعار الرسمي، ممكن تنزّله من [موارد Google الرسمية لعلامة Sign-In](https://developers.google.com/identity/branding-guidelines) وأضيفه كصورة.
- خط عربي مخصص (زي Cairo) هيضيف شكل أحلى لاحقًا — نقدر نضيفه بسهولة بعد كده.

## الخطوة الجاية
تحسينات مستقبلية ممكنة: خط عربي مخصص، إشعارات فورية (Push Notifications) لما حد يقبل الطلب، وتحديث تلقائي للأسعار بالذكاء الاصطناعي.

---

## جهّز التوقيع الرسمي (Release Signing) — لازم للنشر على المتجر

Google Play مش بيقبل تطبيقات موقّعة بمفتاح تجريبي (debug). جهّزتلك مفتاح توقيع حقيقي منفصل عن باقي الملفات (لأسباب أمان — التفاصيل جاية في رسالة منفصلة).

**خطوات الإعداد:**
1. من إعدادات الـ repo بتاعك على GitHub: **Settings → Secrets and variables → Actions → New repository secret**، وضيف الأربع أسرار دول (القيم هتلاقيها في رسالتي المنفصلة اللي فيها ملف الـ keystore):
   - `KEYSTORE_BASE64`
   - `KEYSTORE_PASSWORD`
   - `KEY_ALIAS`
   - `KEY_PASSWORD`
2. خلاص — الـ build الجاي على GitHub Actions هيوقّع الـ APK تلقائيًا بالمفتاح الرسمي بدل التجريبي.

**تحذير مهم جدًا:** ملف الـ keystore وكلمة السر بتاعته **لازم تتحفظ عندك في مكان آمن جدًا** (مدير كلمات سر، أو تخزين سحابي خاص محمي). لو ضاع الملف ده أو الباسورد، **مش هتقدر تنشر أي تحديث تاني لنفس التطبيق على Google Play أبدًا** — هتضطر تنشره كتطبيق جديد بالكامل من الصفر. متسيبوش أبدًا في أي مكان عام أو تشاركه مع حد، ومتحطّوش جوه الـ repo نفسه (خلّيته في `.gitignore` أصلاً كحماية إضافية).

## سياسة الخصوصية (رابط جاهز ومجاني)
عملتلك صفحة سياسة خصوصية (`privacy-policy.html`) جاهزة، وهتستضيفها مجانًا عن طريق GitHub Pages:
1. من الـ repo بتاعك: **Settings → Pages**.
2. تحت "Build and deployment"، اختار **Source: Deploy from a branch**، وبعدين **Branch: main** و **Folder: / (root)**، واحفظ.
3. بعد كام دقيقة، الصفحة هتبقى شغالة على رابط شبه:
   `https://USERNAME.github.io/robabikya/privacy-policy.html`
4. **افتح الملف وحط إيميل تواصل حقيقي بدل `[حط إيميل التواصل بتاعك هنا]`**، بعدين احفظ الرابط ده — هتحتاجه في نموذج النشر على Play Console.

## بعد أول رفعة على Play Console: بصمة SHA-1 الحقيقية
لما ترفع أول نسخة موقّعة (Release) على Google Play Console، جوجل بيفعّل تلقائيًا خاصية **Play App Signing** وبيدّيك بصمة SHA-1 **مختلفة** عن اللي عندك دلوقتي (تلاقيها في Play Console تحت **Release → Setup → App signing**). لازم تضيف البصمة دي كمان في Firebase Console (نفس مكان بصمة الـ debug اللي ضفتها قبل كده)، وإلا تسجيل الدخول بجوجل هيفشل لأي حد نزّل التطبيق من المتجر نفسه.

## مسودة وصف التطبيق لمتجر Google Play
**الوصف القصير (Short description، أقصى 80 حرف):**
> حوّل مخلفاتك القابلة لإعادة التدوير لفلوس، بضغطة واحدة من موبايلك

**الوصف الكامل (Full description):**
> إيكو بيسهّل عليك تحصيل المخلفات القابلة لإعادة التدوير من بيتك أو شغلك، وتاخد فلوسها من غير أي تعب.
>
> بتقدر تطلب تحصيل: عبوات الكانز، ألومنيوم اسكراب، ورق فويل، أطباق ألومنيوم، بلاستيك، كاوتش العربية، وخردة الحديد.
>
> اختار نوع المخلفات والكمية، وشوف سعرها التقريبي فورًا. حدد عنوانك وموقعك على الخريطة، واختار الميعاد المناسب لك، وارفع صورة لو حبيت. هيتواصل معاك فريقنا لتأكيد الميعاد وتحصيل المخلفات من عندك.
>
> التطبيق بيدعم العربي والإنجليزي.

**ملحوظة:** عدّل الوصف ده بما يناسبك، ده بس نقطة بداية توفرلك وقت.

## نموذج "Data safety" في Play Console
هيسألك عن البيانات اللي التطبيق بيجمعها. بناءً على اللي التطبيق فعليًا بيعمله:
- **Personal info:** الاسم، الإيميل، رقم التليفون (بيتجمعوا، مرتبطين بحساب المستخدم، الغرض: تشغيل التطبيق/التواصل).
- **Location:** الموقع الجغرافي التقريبي/الدقيق (بيتجمع، الغرض: تشغيل التطبيق).
- **البيانات بتتشفّر أثناء النقل:** آه (Firebase بيستخدم HTTPS).
- **تقدر تطلب حذف بياناتك:** آه (وضّح إزاي في سياسة الخصوصية، زي إنه يبعت إيميل).

## نشر التطبيق بره جوجل بلاي (رابط تحميل مباشر مجاني)

بالإضافة للنشر على المتاجر، جهّزتلك طريقة تحميل مباشر تناسب أي حد، بضغطة واحدة، من غير أي حساب أو مراجعة.

**إزاي تستخدمها:**
1. افتح `index.html` في جذر المشروع، وغيّر `USERNAME/REPO` في رابط التحميل باسم حسابك واسم الـ repo بتاعك على GitHub.
2. لما تكون جاهز لنشر نسخة عامة، اعمل "تاق" (tag) بدل الـ push العادي:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions هيبني الـ APK زي العادي، لكن كمان هينشره كـ "Release" عام برابط تحميل دائم:
   `https://github.com/USERNAME/REPO/releases/latest/download/app-release.apk`
4. فعّل GitHub Pages (لو لسه معملتهاش من قسم سياسة الخصوصية فوق) — صفحة `index.html` هتبقى شغالة كصفحة تحميل بسيطة تقدر تبعت رابطها لأي حد.

**بدائل تانية مجانية غير جوجل بلاي وآبل** (لو حبيت وصول أوسع بشكل "متجر" رسمي):
- **Samsung Galaxy Store** — مجاني بالكامل، منتشر جدًا في مصر.
- **Huawei AppGallery** — مجاني للمطورين الأفراد، مهم لمستخدمي هواوي.
- **Amazon Appstore** — مجاني، انتشار أقل في مصر.

كل الخيارات دي بتاخد نفس ملف الـ APK اللي بيطلعلك من GitHub Actions، فمش هتحتاج تبني حاجة تانية من الصفر لأي واحد فيهم.

