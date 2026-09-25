class DiseaseRule {
  final String nutrientKey;
  final String nutrientDisplayName;
  final Map<String, double> thresholds;

  DiseaseRule({
    required this.nutrientKey,
    required this.nutrientDisplayName,
    required this.thresholds,
  });
}

final Map<String, DiseaseRule> diseaseRules = {
  "سكري": DiseaseRule(
    nutrientKey: "sugars_100g",
    nutrientDisplayName: "السكر",
    thresholds: {"خفيف": 15.0, "متوسط": 10.0, "شديد": 5.0},
  ),
};
