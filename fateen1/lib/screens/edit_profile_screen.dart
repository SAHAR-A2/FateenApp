import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/choice_question.dart';
import '../widgets/circle_icon_button.dart';
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  String? selectedAllergyName;
  String? selectedSymptom;
  String? selectedDose;

  String? selectedDiseaseName;
  String? selectedMedication;
  String? selectedControl;

  AppUser? _currentUser;
  List<UserAllergy> _allergies = [];
  List<UserDisease> _diseases = [];

  bool _isLoadingProfile = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final userId = AuthService().getCurrentUserId();
      final user = await FirestoreService().getUserProfile(userId!);

      setState(() {
        _currentUser = user;
        userNameController.text = user!.username;
        _allergies = List<UserAllergy>.from(user.allergies);
        _diseases = List<UserDisease>.from(user.diseases);
        _isLoadingProfile = false;
      });
    } catch (errorMessage) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    }
  }

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    confirmController.dispose();
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
            content: Text('أكملي اختيار المرض والعلاج والانضباط أولاً')),
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

  Future<void> _save() async {
    if (passwordController.text.isNotEmpty ||
        confirmController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغيير كلمة المرور غير متاح حاليًا')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedUser = AppUser(
        id: _currentUser!.id,
        username: userNameController.text.trim(),
        allergies: _allergies,
        diseases: _diseases,
      );

      await FirestoreService().saveUserProfile(_currentUser!.id, updatedUser);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (errorMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              Row(children: [const BackCircleButton(), const Spacer()]),
              const SizedBox(height: AppSpacing.sm),
              Text('تعديل الملف الشخصي',
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
                hintText: 'كلمة مرور جديدة (غير متاح حاليًا)',
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              FateenTextField(
                controller: confirmController,
                hintText: 'تأكيد كلمة المرور الجديدة',
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
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text('حفظ التعديلات', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
