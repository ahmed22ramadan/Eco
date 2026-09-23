import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n/app_strings.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String lang;
  final VoidCallback onToggleLang;

  const LoginScreen({super.key, required this.lang, required this.onToggleLang});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;

  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupConfirmCtrl = TextEditingController();
  bool _signupObscure = true;
  bool _signupConfirmObscure = true;
  bool _agreedToTerms = false;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String t(String key) => AppStrings.t(key, widget.lang);

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupConfirmCtrl.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(lang: widget.lang, onToggleLang: widget.onToggleLang),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailCtrl.text.trim();
    final password = _loginPasswordCtrl.text;
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = t('err_email'));
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = t('err_password'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? t('generic_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignup() async {
    final name = _signupNameCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim();
    final password = _signupPasswordCtrl.text;
    final confirm = _signupConfirmCtrl.text;

    if (name.isEmpty) {
      setState(() => _error = t('err_name'));
      return;
    }
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = t('err_email'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = t('err_password_len'));
      return;
    }
    if (password != confirm) {
      setState(() => _error = t('err_password_match'));
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _error = t('err_terms'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(name);
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? t('generic_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) _goHome();
    } catch (_) {
      setState(() => _error = t('generic_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant, width: 0.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(scheme),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: Column(
                        children: [
                          _buildTabSwitcher(scheme),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
                          ],
                          const SizedBox(height: 16),
                          _isLogin ? _buildLoginForm(scheme) : _buildSignupForm(scheme),
                        ],
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

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      color: scheme.primaryContainer,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: TextButton.icon(
              onPressed: widget.onToggleLang,
              icon: const Icon(Icons.language, size: 16),
              label: Text(
                widget.lang == 'ar' ? 'English' : 'عربي',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: scheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: scheme.primary, width: 0.5),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 0.5),
                ),
                child: Icon(Icons.recycling, color: scheme.onPrimaryContainer, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                'إيكو سمارت',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              if (widget.lang == 'en')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Eco-Smart',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onPrimaryContainer.withOpacity(0.75),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                t('brand_tagline'),
                style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer.withOpacity(0.75)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              t('login_tab'),
              _isLogin,
              () => setState(() {
                _isLogin = true;
                _error = null;
              }),
              scheme,
            ),
          ),
          Expanded(
            child: _tabButton(
              t('signup_tab'),
              !_isLogin,
              () => setState(() {
                _isLogin = false;
                _error = null;
              }),
              scheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap, ColorScheme scheme) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: active ? scheme.onPrimary : scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('login_heading'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Text(t('email_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _loginEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@example.com'),
        ),
        const SizedBox(height: 14),
        Text(t('password_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _loginPasswordCtrl,
          obscureText: _loginObscure,
          decoration: InputDecoration(
            hintText: '********',
            suffixIcon: IconButton(
              icon: Icon(_loginObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(t('forgot_password'), style: TextStyle(fontSize: 13, color: scheme.primary)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _loading ? null : _handleLogin,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t('login_button')),
        ),
        const SizedBox(height: 18),
        _buildDivider(scheme),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loading ? null : _handleGoogleSignIn,
          icon: const Icon(Icons.account_circle_outlined, size: 20),
          label: Text(t('google_login')),
        ),
        const SizedBox(height: 18),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(t('no_account'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              GestureDetector(
                onTap: () => setState(() {
                  _isLogin = false;
                  _error = null;
                }),
                child: Text(t('signup_link'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignupForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('signup_heading'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Text(t('name_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(controller: _signupNameCtrl),
        const SizedBox(height: 14),
        Text(t('email_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _signupEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@example.com'),
        ),
        const SizedBox(height: 14),
        Text(t('password_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _signupPasswordCtrl,
          obscureText: _signupObscure,
          decoration: InputDecoration(
            suffixIcon: IconButton(
              icon: Icon(_signupObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              onPressed: () => setState(() => _signupObscure = !_signupObscure),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(t('confirm_password_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _signupConfirmCtrl,
          obscureText: _signupConfirmObscure,
          decoration: InputDecoration(
            suffixIcon: IconButton(
              icon: Icon(_signupConfirmObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              onPressed: () => setState(() => _signupConfirmObscure = !_signupConfirmObscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v ?? false)),
            Expanded(
              child: Text(t('terms_label'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
        FilledButton(
          onPressed: _loading ? null : _handleSignup,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t('signup_button')),
        ),
        const SizedBox(height: 18),
        _buildDivider(scheme),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loading ? null : _handleGoogleSignIn,
          icon: const Icon(Icons.account_circle_outlined, size: 20),
          label: Text(t('google_signup')),
        ),
        const SizedBox(height: 18),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(t('have_account'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              GestureDetector(
                onTap: () => setState(() {
                  _isLogin = true;
                  _error = null;
                }),
                child: Text(t('login_link'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(t('or_divider'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}
