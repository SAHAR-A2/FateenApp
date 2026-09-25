import 'allergy_options.dart';
import 'disease_options.dart';

String calculateAllergySeverity(String symptom, String toleranceDose) {
  final symptomIndex = allergySymptoms.indexOf(symptom);
  final doseIndex = toleranceDoseOptions.indexOf(toleranceDose);

  if (symptomIndex == 2) {
    return "شديد";
  }

  if (doseIndex == 1) {
    return "شديد";
  }

  if (doseIndex == 0) {
    return "متوسط";
  }

  return "خفيف";
}

String calculateDiseaseSeverity(String takesMedication, String controlStatus) {
  final medicationIndex = diseaseMedicationOptions.indexOf(takesMedication);
  final controlIndex = diseaseControlStatusOptions.indexOf(controlStatus);

  if (medicationIndex == 2 && controlIndex == 2) {
    return "شديد";
  }

  if (controlIndex == 1) {
    return "متوسط";
  }

  if (medicationIndex == 0 && controlIndex == 0) {
    return "خفيف";
  }

  return "متوسط";
}
