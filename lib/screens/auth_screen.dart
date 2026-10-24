import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/provider_service.dart';
import '../services/role_provider.dart';
import 'main_shell.dart';
import 'provider_profile_setup_screen.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _resending = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = ref.watch(selectedRoleProvider);
    final roleLabel = role == "Provider" ? "Service Provider" : "User";

    return Scaffold(
      backgroundColor: kPrimaryPurple,
      appBar: AppBar(backgroundColor: kPrimaryPurple, foregroundColor: Colors.white, elevation: 0, actions: const [LanguageButton()]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              LText(
                _isLogin ? "Welcome Back" : "Create your account",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              LText(
                '${tr(context, roleLabel)} • ${tr(context, _isLogin ? "Sign in to continue" : "Sign up to get started")}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F1FE),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isLogin = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isLogin ? kPrimaryPurple : Colors.transparent,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: LText(
                                  "Login",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isLogin ? Colors.white : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isLogin = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isLogin ? kPrimaryPurple : Colors.transparent,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: LText(
                                  "Register",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isLogin ? Colors.white : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!_isLogin) ...[
                      _buildLabel("Full name"),
                      _buildField(_nameController, "Enter your name"),
                      const SizedBox(height: 14),
                    ],

                    _buildLabel("Email address"),
                    _buildField(_emailController, "Enter your email address",
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),

                    _buildLabel("Password"),
                    _buildField(
                      _passwordController,
                      "Enter password",
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),

                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: LText(
                          authState.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: authState.isLoading ? null : _handleSubmit,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : LText(
                                _isLogin ? "Login" : "Register",
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),

                    TextButton(onPressed: _resending ? null : () async {
                      setState(() => _resending = true);
                      final result = await AuthService.resendConfirmation(_emailController.text);
                      if (!mounted || !context.mounted) return;
                      setState(() => _resending = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LText(result['success'] == true
                        ? 'If your account needs verification, a confirmation message will be sent to its registered email.' : result['message'].toString())));
                    }, child: LText(_resending ? 'Sending...' : 'Resend account verification email')),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black54),
                          children: [
                            TextSpan(
                              text: tr(context, _isLogin
                                  ? "Don't have an account? "
                                  : "Already have an account? "),
                            ),
                            TextSpan(
                              text: tr(context, _isLogin ? "Sign up" : "Sign in"),
                              style: const TextStyle(
                                color: kPrimaryPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: LText(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textDirection: keyboardType == TextInputType.emailAddress || obscure ? TextDirection.ltr : null,
      decoration: InputDecoration(
        hintText: tr(context, hint),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF3F1FE),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final role = ref.read(selectedRoleProvider);

    if (_isLogin) {
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (success && mounted) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final actualRole = prefs.getString('role') ?? 'Customer';
        ref.read(selectedRoleProvider.notifier).state = actualRole;
        if (actualRole == "Provider") {
          final profileResult = await ProviderService.getMyProfile();
          if (profileResult["sessionExpired"] == true) return;
          if (!mounted) return;
          if (profileResult['success'] != true && profileResult['notFound'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: LText('Unable to load your profile. Please try again.')));
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => profileResult["success"] == true
                  ? const MainShell()
                  : const ProviderProfileSetupScreen(),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        }
      }
    } else {
      final success = await ref.read(authProvider.notifier).register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
            role,
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText("تم استلام التسجيل. أكّد بريدك الإلكتروني ثم سجّل الدخول.")),
        );
        setState(() => _isLogin = true);
      }
    }
  }
}
