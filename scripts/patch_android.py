"""
يتنفذ تلقائيًا أثناء GitHub Actions بعد أمر `flutter create`.
بيعدّل مشروع أندرويد المُولَّد عشان:
1. يضيف صلاحيات الإنترنت والكاميرا والموقع.
2. يخلي اسم التطبيق "Eco" ظاهر برّه التطبيق (الشاشة الرئيسية ومتجر التطبيقات).
3. يضيف Google Services Gradle plugin عشان Firebase يشتغل فعليًا.

مهم جدًا: كل خطوة بتتأكد بنفسها إنها فعلاً غيّرت حاجة، ولو فشلت
بتوقف الـ build بخطأ واضح فورًا - عشان مانوصلش لموقف إن الـ build
"ينجح" وهو فعليًا مالوش أي تأثير حقيقي.
"""
import re
import sys
import pathlib


def fail(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)
    sys.exit(1)


# 1) AndroidManifest.xml: الصلاحيات + الاسم بالعربي
manifest_path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not manifest_path.exists():
    fail(f"الملف مش موجود: {manifest_path}")

manifest = manifest_path.read_text(encoding="utf-8")
extra_permissions = (
    '\n    <uses-permission android:name="android.permission.INTERNET"/>'
    '\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>'
    '\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>'
    '\n    <queries>'
    '\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>'
    '\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="geo"/></intent>'
    '\n    </queries>'
)
if "android.permission.INTERNET" not in manifest:
    new_manifest = re.sub(r"(<manifest[^>]*>)", r"\1" + extra_permissions, manifest, count=1)
    if new_manifest == manifest:
        fail("فشل في إضافة الصلاحيات لـ AndroidManifest.xml (مفيش تاج <manifest> اتلقى).")
    manifest = new_manifest

new_manifest = re.sub(r'android:label="[^"]*"', 'android:label="Eco"', manifest)
if 'android:label="Eco"' not in new_manifest:
    fail("فشل في تغيير اسم التطبيق في AndroidManifest.xml.")
manifest_path.write_text(new_manifest, encoding="utf-8")
print("تم تعديل AndroidManifest.xml بنجاح.")


def patch_plugin_block(path: pathlib.Path, insert_line: str) -> None:
    """يضيف سطر بلجن جوه أول plugins {} block، بيجرب أكتر من نقطة إدراج معروفة."""
    content = path.read_text(encoding="utf-8")
    if "com.google.gms.google-services" in content:
        print(f"{path}: البلجن موجود بالفعل، تخطي.")
        return

    anchors = [
        'id("com.android.application")',
        'id "com.android.application"',
        'id("kotlin-android")',
        'id "kotlin-android"',
    ]
    for anchor in anchors:
        if anchor in content:
            new_content = content.replace(anchor, anchor + "\n    " + insert_line, 1)
            path.write_text(new_content, encoding="utf-8")
            # تأكيد نهائي: نعيد قراءة الملف من القرص ونتأكد إن التعديل فعلاً اتسجل
            verify = path.read_text(encoding="utf-8")
            if "com.google.gms.google-services" not in verify:
                fail(f"{path}: اتكتب الملف لكن التعديل مش موجود بعد إعادة القراءة!")
            print(f"{path}: تم إضافة google-services plugin بنجاح (بعد '{anchor}').")
            return

    fail(
        f"{path}: مالقيتش أي نقطة إدراج معروفة (جرّبت: {anchors}).\n"
        f"محتوى الملف الحالي عشان تشوفه في الـ log:\n{content}"
    )


def patch_application_id(path: pathlib.Path, is_kts: bool) -> None:
    """
    flutter create --org com.robabikya --project-name robabikya بيولّد
    applicationId = com.robabikya.robabikya (org + اسم المشروع مع بعض)،
    مش com.robabikya.app اللي متسجل في Firebase Console. نثبّته هنا صراحةً
    عشان يطابق التسجيل بالظبط.
    """
    content = path.read_text(encoding="utf-8")
    target = "com.robabikya.app"

    if is_kts:
        pattern = r'applicationId\s*=\s*"[^"]+"'
        replacement = f'applicationId = "{target}"'
    else:
        pattern = r'applicationId\s+"[^"]+"'
        replacement = f'applicationId "{target}"'

    match = re.search(pattern, content)
    if not match:
        fail(f"{path}: مالقيتش سطر applicationId. محتوى الملف:\n{content}")

    new_content = re.sub(pattern, replacement, content, count=1)
    path.write_text(new_content, encoding="utf-8")

    verify = path.read_text(encoding="utf-8")
    if f'"{target}"' not in verify:
        fail(f"{path}: اتكتب applicationId لكن القيمة الجديدة مش موجودة بعد إعادة القراءة!")
    print(f"{path}: applicationId اتظبط على {target}.")


# 2) android/app/build.gradle(.kts): applicationId الصحيح + Google Services plugin
app_gradle_kts = pathlib.Path("android/app/build.gradle.kts")
app_gradle_groovy = pathlib.Path("android/app/build.gradle")

if app_gradle_kts.exists():
    patch_application_id(app_gradle_kts, is_kts=True)
    patch_plugin_block(app_gradle_kts, 'id("com.google.gms.google-services")')
elif app_gradle_groovy.exists():
    patch_application_id(app_gradle_groovy, is_kts=False)
    patch_plugin_block(app_gradle_groovy, 'id "com.google.gms.google-services"')
else:
    fail("مفيش android/app/build.gradle ولا build.gradle.kts — يبدو إن flutter create فشل قبل الخطوة دي.")


# 3) android/settings.gradle(.kts): تسجيل نسخة الـ plugin
settings_kts = pathlib.Path("android/settings.gradle.kts")
settings_groovy = pathlib.Path("android/settings.gradle")

if settings_kts.exists():
    settings_path = settings_kts
    version_line = 'id("com.google.gms.google-services") version "4.4.2" apply false'
    anchor_pattern = r'id\("com\.android\.application"\)\s+version\s+"[^"]+"\s+apply\s+false'
elif settings_groovy.exists():
    settings_path = settings_groovy
    version_line = 'id "com.google.gms.google-services" version "4.4.2" apply false'
    anchor_pattern = r'id "com\.android\.application" version "[^"]+" apply false'
else:
    fail("مفيش android/settings.gradle ولا settings.gradle.kts.")

content = settings_path.read_text(encoding="utf-8")
if "com.google.gms.google-services" in content:
    print(f"{settings_path}: البلجن مسجل بالفعل، تخطي.")
else:
    match = re.search(anchor_pattern, content)
    if not match:
        fail(
            f"{settings_path}: مالقتش سطر 'com.android.application version ... apply false'.\n"
            f"محتوى الملف الحالي عشان تشوفه في الـ log:\n{content}"
        )
    new_content = content[: match.end()] + "\n    " + version_line + content[match.end() :]
    settings_path.write_text(new_content, encoding="utf-8")
    verify = settings_path.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in verify:
        fail(f"{settings_path}: اتكتب الملف لكن التعديل مش موجود بعد إعادة القراءة!")
    print(f"{settings_path}: تم تسجيل نسخة google-services plugin بنجاح.")

print("تم تعديل مشروع أندرويد بنجاح فعليًا (اتأكد من كل خطوة).")


def patch_signing_config(path: pathlib.Path, is_kts: bool) -> None:
    """
    بيضيف إعدادات التوقيع الرسمي (release signing) في آخر الملف، من غير
    ما يلمس أي حاجة في المحتوى الأصلي اللي flutter create ولّده. القيم
    (كلمة السر، اسم الـ alias...) بتتقرا وقت البناء من ملف android/key.properties
    اللي GitHub Actions بيبنيه من الـ Secrets — الملف ده متسجّلش في git خالص.
    لو الملف مش موجود (يعني حد بيبني محليًا من غير ما يجهّز مفتاح توقيع)،
    البناء بيرجع تلقائيًا لتوقيع debug عادي بدل ما يفشل.
    """
    content = path.read_text(encoding="utf-8")
    if "keystorePropertiesFile" in content:
        print(f"{path}: إعدادات التوقيع الرسمي موجودة بالفعل، تخطي.")
        return

    if is_kts:
        snippet = '''

// --- إعداد التوقيع الرسمي (release signing) — مُضاف تلقائيًا ---
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}
'''
    else:
        snippet = '''

// --- إعداد التوقيع الرسمي (release signing) — مُضاف تلقائيًا ---
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
            }
        }
    }
    buildTypes {
        release {
            signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
        }
    }
}
'''

    new_content = content + snippet
    path.write_text(new_content, encoding="utf-8")
    verify = path.read_text(encoding="utf-8")
    if "keystorePropertiesFile" not in verify:
        fail(f"{path}: اتكتبت إعدادات التوقيع لكنها مش موجودة بعد إعادة القراءة!")
    print(f"{path}: تم إضافة إعدادات التوقيع الرسمي بنجاح.")


if app_gradle_kts.exists():
    patch_signing_config(app_gradle_kts, is_kts=True)
else:
    patch_signing_config(app_gradle_groovy, is_kts=False)

print("خلصنا كل خطوات تعديل مشروع أندرويد.")
