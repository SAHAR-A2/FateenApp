import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/fateen_text_field.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = userNameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم المستخدم وكلمة المرور')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await AuthService().signInWithUsername(username, password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              children: [
                Text('مرحبا بك..', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xl),
                FateenTextField(
                  controller: userNameController,
                  hintText: 'اسم المستخدم',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                FateenTextField(
                  controller: passwordController,
                  hintText: 'كلمة المرور',
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('هذه الميزة غير متاحة حالياً')),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                    ),
                    child:
                        Text('هل نسيت كلمة المرور؟', style: AppTextStyles.link),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _login,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text('تسجيل الدخول', style: AppTextStyles.button),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text('ليس لديك حساب؟ سجل الآن',
                      style: AppTextStyles.link),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
