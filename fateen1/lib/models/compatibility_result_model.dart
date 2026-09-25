// `unknown` was added alongside the FATEEN backend migration. Previously
// this enum only had 4 values and `insufficientData` covered both "we
// don't have enough product data" AND "we have no rule to evaluate this
// allergy/condition against" -- the backend now distinguishes those two
// cases (see app/schemas/compatibility.py STATUS_UNKNOWN vs
// STATUS_INSUFFICIENT_DATA), so the client model preserves that
// distinction too rather than silently re-merging it. `unknown` currently
// maps to the same 'unknown' UI key as `insufficientData` below, so this
// is additive only -- no screen's visual rendering changes because of it.
enum ResultStatus { green, orange, red, insufficientData, unknown }

class CompatibilityResult {
  final ResultStatus status;
  final String reason;
  final String? matchedTag;

  CompatibilityResult({
    required this.status,
    required this.reason,
    this.matchedTag,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status.toString().split('.').last,
      'reason': reason,
      'matchedTag': matchedTag,
    };
  }

  factory CompatibilityResult.fromJson(Map<String, dynamic> json) {
    return CompatibilityResult(
      status: ResultStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => ResultStatus.insufficientData,
      ),
      reason: json['reason'] ?? '',
      matchedTag: json['matchedTag'],
    );
  }

  /// Parses the FATEEN backend's `CompatibilityResponse`
  /// (POST /api/v1/products/barcode/{barcode}/compatibility), which is a
  /// different shape from the legacy local `toJson`/`fromJson` above
  /// (those round-trip this class's own shape; this parses the backend's
  /// contract). The backend's five-state `status` string maps directly
  /// onto ResultStatus -- this is a straight rename/mapping, not a new
  /// decision: the backend already decided SAFE/WARNING/DANGER/UNKNOWN/
  /// INSUFFICIENT_DATA before this JSON was produced.
  factory CompatibilityResult.fromBackendJson(Map<String, dynamic> json) {
    const statusMap = {
      'SAFE': ResultStatus.green,
      'WARNING': ResultStatus.orange,
      'DANGER': ResultStatus.red,
      'UNKNOWN': ResultStatus.unknown,
      'INSUFFICIENT_DATA': ResultStatus.insufficientData,
    };
    final matchedAllergens = json['matched_allergens'] as List?;
    return CompatibilityResult(
      status: statusMap[json['status']] ?? ResultStatus.unknown,
      reason: json['reason'] ?? '',
      matchedTag: (matchedAllergens != null && matchedAllergens.isNotEmpty)
          ? matchedAllergens.first['source_tag'] as String?
          : null,
    );
  }
}

extension ResultStatusUiMapping on ResultStatus {
  String get uiKey {
    switch (this) {
      case ResultStatus.red:
        return 'danger';
      case ResultStatus.orange:
        return 'warning';
      case ResultStatus.green:
        return 'safe';
      case ResultStatus.insufficientData:
        return 'unknown';
      case ResultStatus.unknown:
        return 'unknown';
    }
  }
}
