class UserAllergy {
  final String tag;
  final String symptom;
  final String toleranceDose;
  final String severity;

  UserAllergy({
    required this.tag,
    required this.symptom,
    required this.toleranceDose,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'symptom': symptom,
      'toleranceDose': toleranceDose,
      'severity': severity,
    };
  }

  factory UserAllergy.fromJson(Map<String, dynamic> json) {
    return UserAllergy(
      tag: json['tag'],
      symptom: json['symptom'],
      toleranceDose: json['toleranceDose'],
      severity: json['severity'],
    );
  }
}

class UserDisease {
  final String name;
  final String takesMedication;
  final String controlStatus;
  final String severity;

  UserDisease({
    required this.name,
    required this.takesMedication,
    required this.controlStatus,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'takesMedication': takesMedication,
        'controlStatus': controlStatus,
        'severity': severity,
      };

  factory UserDisease.fromJson(Map<String, dynamic> json) {
    return UserDisease(
      name: json['name'],
      takesMedication: json['takesMedication'],
      controlStatus: json['controlStatus'],
      severity: json['severity'],
    );
  }
}

class AppUser {
  final String id;
  final String username;
  final List<UserAllergy> allergies;
  final List<UserDisease> diseases;

  AppUser({
    required this.id,
    required this.username,
    required this.allergies,
    required this.diseases,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'allergies': allergies.map((a) => a.toJson()).toList(),
      'diseases': diseases.map((d) => d.toJson()).toList(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'],
      allergies: (json['allergies'] as List)
          .map((item) => UserAllergy.fromJson(item))
          .toList(),
      diseases: (json['diseases'] as List)
          .map((item) => UserDisease.fromJson(item))
          .toList(),
    );
  }
}
