import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EcoSmartApp());
}

class EcoSmartApp extends StatefulWidget {
  const EcoSmartApp({super.key});

  @override
  State<EcoSmartApp> createState() => _EcoSmartAppState();
}

class _EcoSmartAppState extends State<EcoSmartApp> {
  // اللغة الافتراضية عربي؛ العميل يقدر يغيّرها من الزرار في شاشة الدخول/الرئيسية.
  String _lang = 'ar';
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initFirebase();
  }

  Future<void> _initFirebase() {
    // مهلة 15 ثانية: لو الاتصال بـ Firebase علّق لأي سبب، هيظهر خطأ واضح
    // بدل ما التطبيق يفضل واقف على شاشة اللوجو للأبد من غير تفسير.
    return Firebase.initializeApp().timeout(const Duration(seconds: 15));
  }

  void _toggleLang() {
    setState(() => _lang = _lang == 'ar' ? 'en' : 'ar');
  }

  void _retryInit() {
    setState(() => _initFuture = _initFirebase());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Eco-Smart',
        theme: AppTheme.lightTheme,
        home: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, initSnapshot) {
            if (initSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (initSnapshot.hasError) {
              return _FirebaseErrorScreen(error: initSnapshot.error, onRetry: _retryInit);
            }
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                if (authSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (authSnapshot.hasData) {
                  return HomeScreen(lang: _lang, onToggleLang: _toggleLang);
                }
                return LoginScreen(lang: _lang, onToggleLang: _toggleLang);
              },
            );
          },
        ),
      ),
    );
  }
}

/// شاشة توضح رسالة الخطأ الحقيقية لو الاتصال بـ Firebase فشل، بدل شاشة فاضية.
class _FirebaseErrorScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _FirebaseErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'حصل خطأ أثناء الاتصال بـ Firebase',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$error',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: onRetry, child: const Text('حاول تاني')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
