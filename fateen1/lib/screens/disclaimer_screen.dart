import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../widgets/circle_icon_button.dart';

/// صفحة الشروط والسياسات وإخلاء المسؤولية.
/// توضح للمستخدم أن نتائج التطبيق تقديرية وتعتمد على بيانات قد تكون
/// غير مكتملة أو غير دقيقة، وأن مسؤولية القرار النهائي (خصوصًا في
/// الحالات الحساسة) تقع على المستخدم واستشارة مختص عند الشك.
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  static const _sections = <_DisclaimerSection>[
    _DisclaimerSection(
      icon: Icons.info_outline_rounded,
      title: 'طبيعة النتائج',
      body:
          'نتائج تطبيق فطين تقديرية، وتُبنى على البيانات المتاحة عن المنتج أو الطبق '
          '(من قواعد بيانات خارجية أو تحليل صورة بالذكاء الاصطناعي) ومقارنتها بالحساسيات '
          'والأمراض المسجّلة في ملفك الشخصي. هذه النتائج لا تُغني عن قراءة الملصق الغذائي '
          'ولا عن استشارة طبيب أو أخصائي تغذية.',
    ),
    _DisclaimerSection(
      icon: Icons.warning_amber_rounded,
      title: 'احتمال الخطأ',
      body:
          'قد تكون بيانات المنتج في قاعدة البيانات ناقصة أو قديمة، وقد يخطئ الذكاء الاصطناعي '
          'في تقدير مكونات الطبق من الصورة. لا يتحمّل التطبيق أو فريق فطين مسؤولية أي ضرر ناتج '
          'عن الاعتماد الكامل على نتيجة غير دقيقة دون التحقق بنفسك، خصوصًا في حالات الحساسية الشديدة.',
    ),
    _DisclaimerSection(
      icon: Icons.medical_services_outlined,
      title: 'الحالات الحرجة',
      body:
          'إذا كانت حالتك الصحية تستدعي حذرًا شديدًا (كحساسية قد تسبب صدمة تحسسية)، يُرجى دائمًا '
          'التحقق يدويًا من المكونات وعدم الاعتماد فقط على نتيجة التطبيق قبل الاستهلاك.',
    ),
    _DisclaimerSection(
      icon: Icons.lock_outline_rounded,
      title: 'بياناتك',
      body:
          'المعلومات الصحية التي تدخلها (الحساسيات والأمراض المزمنة) تُستخدم فقط لتوليد نتائج '
          'التوافق الخاصة بك داخل التطبيق، ولا تتم مشاركتها مع أي جهة خارجية.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BackCircleButton(),
                  const Spacer(),
                  Text('إخلاء المسؤولية', style: AppTextStyles.subtitle),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in _sections) ...[
                        _SectionCard(section: section),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  child: Text('فهمت، رجوع', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final _DisclaimerSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(section.icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(section.title, style: AppTextStyles.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            section.body,
            textAlign: TextAlign.right,
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerSection {
  const _DisclaimerSection(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}
