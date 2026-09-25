import 'package:fateen/models/product_model.dart';
import 'package:fateen/models/user_model.dart';
import 'package:fateen/models/compatibility_result_model.dart';
import 'package:fateen/data/disease_rules.dart';
import '../data/allergy_options.dart';
import '../models/dish_model.dart';

class HealthChecker {
  /// Reverse lookup: "en:wheat" -> "قمح"، تستخدم لإظهار اسم المسبب
  /// بالعربي داخل رسالة النتيجة بدل رسالة عامة موحدة.
  String? _allergyDisplayName(String tag) {
    for (final entry in allergyTagMap.entries) {
      if (entry.value == tag) return entry.key;
    }
    return null;
  }

  CompatibilityResult checkFullCompatibility(Product product, AppUser user) {
    if (product.hasInsufficientData()) {
      return CompatibilityResult(
        status: ResultStatus.insufficientData,
        reason: 'لا تتوفر بيانات كافية عن مكونات هذا المنتج',
      );
    }

    final allergyResult = _checkAllergies(product, user.allergies);
    if (allergyResult.status == ResultStatus.red) {
      return allergyResult;
    }

    final diseaseResult = _checkDiseases(product, user.diseases);

    return _pickWorseResult(allergyResult, diseaseResult);
  }

  CompatibilityResult _checkAllergies(
    Product product,
    List<UserAllergy> allergies,
  ) {
    for (UserAllergy allergy in allergies) {
      if (product.allergenTags.contains(allergy.tag)) {
        final allergenName = _allergyDisplayName(allergy.tag) ?? allergy.tag;

        if (allergy.severity == 'خفيف') {
          return CompatibilityResult(
            status: ResultStatus.orange,
            reason:
                'هذا المنتج لا يتناسب تمامًا مع حالتك الصحية بسبب وجود ($allergenName)، وقد يسبب لك حساسية خفيفة',
            matchedTag: allergy.tag,
          );
        } else {
          return CompatibilityResult(
            status: ResultStatus.red,
            reason:
                'هذا المنتج لا يتناسب مع حالتك الصحية بسبب وجود ($allergenName)، ويُنصح بتجنبه تمامًا',
            matchedTag: allergy.tag,
          );
        }
      }
    }

    return CompatibilityResult(
      status: ResultStatus.green,
      reason: 'هذا المنتج آمن، ولا يحتوي على أي من مسببات حساسيتك',
    );
  }

  CompatibilityResult _checkDiseases(
    Product product,
    List<UserDisease> diseases,
  ) {
    ResultStatus worstStatus = ResultStatus.green;
    String worstReason = 'هذا المنتج مناسب لحالتك الصحية';

    for (UserDisease disease in diseases) {
      final rule = diseaseRules[disease.name];
      if (rule == null) continue;

      final actualValue =
          (product.nutriments[rule.nutrientKey] ?? 0).toDouble();
      final threshold = rule.thresholds[disease.severity];
      if (threshold == null) continue;

      if (actualValue > threshold * 1.5) {
        worstStatus = ResultStatus.red;
        worstReason =
            'هذا المنتج لا يتناسب مع حالتك الصحية بسبب ارتفاع نسبة (${rule.nutrientDisplayName}) بشكل كبير، وهو غير مناسب لحالة ${disease.name} لديك';
        break;
      } else if (actualValue > threshold) {
        worstStatus = ResultStatus.orange;
        worstReason =
            'هذا المنتج لا يتناسب تمامًا مع حالتك الصحية بسبب ارتفاع نسبة (${rule.nutrientDisplayName}) عن المعتاد بالنسبة لحالة ${disease.name} لديك';
      }
    }

    return CompatibilityResult(status: worstStatus, reason: worstReason);
  }

  CompatibilityResult _pickWorseResult(
    CompatibilityResult a,
    CompatibilityResult b,
  ) {
    const severityOrder = {
      ResultStatus.red: 3,
      ResultStatus.orange: 2,
      ResultStatus.green: 1,
      ResultStatus.insufficientData: 0,
    };

    if (severityOrder[a.status]! >= severityOrder[b.status]!) {
      return a;
    } else {
      return b;
    }
  }

  CompatibilityResult checkDishCompatibility(Dish dish, AppUser user) {
    if (dish.estimatedIngredients.isEmpty) {
      return CompatibilityResult(
        status: ResultStatus.insufficientData,
        reason: 'تعذر تحديد مكونات واضحة من الصورة',
      );
    }

    for (UserAllergy allergy in user.allergies) {
      final allergyName = allergyTagMap.entries
          .firstWhere((e) => e.value == allergy.tag,
              orElse: () => const MapEntry('', ''))
          .key;
      if (allergyName.isEmpty) continue;

      final matched = dish.estimatedIngredients
          .any((ingredient) => ingredient.contains(allergyName));

      if (matched) {
        if (allergy.severity == 'خفيف') {
          return CompatibilityResult(
            status: ResultStatus.orange,
            reason:
                'هذا الطبق لا يتناسب تمامًا مع حالتك الصحية بسبب احتمال وجود ($allergyName)، وقد يسبب لك حساسية خفيفة',
          );
        } else {
          return CompatibilityResult(
            status: ResultStatus.red,
            reason:
                'هذا الطبق لا يتناسب مع حالتك الصحية بسبب احتمال وجود ($allergyName)، ويُنصح بتجنبه',
          );
        }
      }
    }

    return CompatibilityResult(
      status: ResultStatus.green,
      reason:
          'لا تظهر بمكونات الطبق أي من مسببات حساسيتك المعروفة (تقدير بالذكاء الاصطناعي، قد لا يكون دقيقاً 100%)',
    );
  }
}
