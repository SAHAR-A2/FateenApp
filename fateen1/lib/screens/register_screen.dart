import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/choice_question.dart';
import '../widgets/fateen_text_field.dart';
import '../widgets/section_title.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tag_dropdown_row.dart';
import '../data/allergy_options.dart';
import '../data/disease_options.dart';
import '../data/severity_calculator.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? selectedAllergyName;
  String? selectedSymptom;
  String? selectedDose;

  String? selectedDiseaseName;
  String? selectedMedication;
  String? selectedControl;

  final List<UserAllergy> _allergies = [];
  final List<UserDisease> _diseases = [];

  bool _isSubmitting = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _addAllergy() {
    if (selectedAllergyName == null ||
        selectedSymptom == null ||
        selectedDose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('أكمل اختيار الحساسية والعرض والجرعة أولاً')),
      );
      return;
    }

    final severity = calculateAllergySeverity(selectedSymptom!, selectedDose!);

    setState(() {
      _allergies.add(UserAllergy(
        tag: allergyTagMap[selectedAllergyName]!,
        symptom: selectedSymptom!,
        toleranceDose: selectedDose!,
        severity: severity,
      ));
      selectedAllergyName = null;
      selectedSymptom = null;
      selectedDose = null;
    });
  }

  void _addDisease() {
    if (selectedDiseaseName == null ||
        selectedMedication == null ||
        selectedControl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('أكمل اختيار المرض والعلاج والانضباط أولاً')),
      );
      return;
    }

    final severity =
        calculateDiseaseSeverity(selectedMedication!, selectedControl!);

    setState(() {
      _diseases.add(UserDisease(
        name: selectedDiseaseName!,
        takesMedication: selectedMedication!,
        controlStatus: selectedControl!,
        severity: severity,
      ));
      selectedDiseaseName = null;
      selectedMedication = null;
      selectedControl = null;
    });
  }

  Future<void> _submit() async {
    final username = userNameController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تعبئة جميع الحقول')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء الموافقة على الشروط والسياسات وإخلاء المسؤولية للمتابعة')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firebaseUser =
          await AuthService().registerWithUsername(username, password);

      final appUser = AppUser(
        id: firebaseUser!.uid,
        username: username,
        allergies: _allergies,
        diseases: _diseases,
      );

      await FirestoreService().saveUserProfile(firebaseUser.uid, appUser);

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
    final remainingAllergies = allergyTagMap.keys
        .where((name) => !_allergies.any((a) => a.tag == allergyTagMap[name]))
        .toList();
    final remainingDiseases = chronicDiseases
        .where((name) => !_diseases.any((d) => d.name == name))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('مرحبا بك..',
                  textAlign: TextAlign.center, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.fieldGap),
              FateenTextField(
                controller: confirmPasswordController,
                hintText: 'تأكيد كلمة المرور',
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionTitle('أنواع الحساسية'),
              const SizedBox(height: AppSpacing.sm),
              TagDropdownRow(
                value: selectedAllergyName,
                options: remainingAllergies,
                onChanged: (v) => setState(() => selectedAllergyName = v),
                onAdd: _addAllergy,
              ),
              if (selectedAllergyName != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ChoiceQuestion(
                  question:
                      'في حال تعرضت للحساسية، ما هي أقصى أعراض شعرت بها سابقًا؟',
                  options: allergySymptoms,
                  selectedValue: selectedSymptom,
                  onSelected: (v) => setState(() => selectedSymptom = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                ChoiceQuestion(
                  question: 'ما هي أقل كمية تسببت لك في رد فعل؟',
                  options: toleranceDoseOptions,
                  selectedValue: selectedDose,
                  onSelected: (v) => setState(() => selectedDose = v),
                ),
              ],
              if (_allergies.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.smMd),
                ..._allergies.map((a) {
                  final name = allergyTagMap.entries
                      .firstWhere((e) => e.value == a.tag)
                      .key;
                  return TagChip(
                    label: name,
                    onRemove: () => setState(() => _allergies.remove(a)),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionTitle('الأمراض المزمنة'),
              const SizedBox(height: AppSpacing.sm),
              TagDropdownRow(
                value: selectedDiseaseName,
                options: remainingDiseases,
                onChanged: (v) => setState(() => selectedDiseaseName = v),
                onAdd: _addDisease,
              ),
              if (selectedDiseaseName != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ChoiceQuestion(
                  question: 'هل تأخذ العلاج بانتظام؟',
                  options: diseaseMedicationOptions,
                  selectedValue: selectedMedication,
                  onSelected: (v) => setState(() => selectedMedication = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                ChoiceQuestion(
                  question: 'هل الحالة مضبوطة عادةً؟',
                  options: diseaseControlStatusOptions,
                  selectedValue: selectedControl,
                  onSelected: (v) => setState(() => selectedControl = v),
                ),
              ],
              if (_diseases.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.smMd),
                ..._diseases.map((d) => TagChip(
                      label: d.name,
                      onRemove: () => setState(() => _diseases.remove(d)),
                    )),
              ],
              const SizedBox(height: AppSpacing.lg),
              _TermsAgreementRow(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                onOpenDisclaimer: () =>
                    Navigator.pushNamed(context, '/disclaimer'),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text('الصفحة الرئيسية', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مربع اختيار صغير أسفل نموذج التسجيل: موافقة إلزامية على الشروط
/// والسياسات وإخلاء المسؤولية قبل إنشاء الحساب. الضغط على الرابط
/// يفتح صفحة إخلاء المسؤولية الكاملة (`/disclaimer`).
class _TermsAgreementRow extends StatelessWidget {
  const _TermsAgreementRow({
    required this.value,
    required this.onChanged,
    required this.onOpenDisclaimer,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDisclaimer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            behavior: HitTestBehavior.opaque,
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                style: AppTextStyles.caption,
                children: [
                  const TextSpan(text: 'أوافق على '),
                  TextSpan(
                    text: 'الشروط والسياسات وإخلاء المسؤولية',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = onOpenDisclaimer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
