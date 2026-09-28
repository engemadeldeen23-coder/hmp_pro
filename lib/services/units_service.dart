// ============================================================
//  UNITS CONVERSION SERVICE
//  Two systems supported:
//    - SI Standard: mm, MN/m², m/s
//    - Metric (Engineering): cm, kgf/cm², cm/s
// ============================================================

class UnitsService {
  static const String SI = 'SI';           // mm, MN/m², m/s
  static const String METRIC = 'METRIC';   // cm, kgf/cm², cm/s

  // Conversion factors
  // 1 MN/m² = 10.197162 kgf/cm²
  static const double MNM2_TO_KGFCM2 = 10.197162;
  // 1 mm = 0.1 cm
  static const double MM_TO_CM = 0.1;
  // 1 m/s = 100 cm/s
  static const double MS_TO_CMS = 100.0;

  static String _system = SI;

  static String get system => _system;

  static void setSystem(String s) {
    _system = s == METRIC ? METRIC : SI;
  }

  static bool get isMetric => _system == METRIC;
  static bool get isSI => _system == SI;

  // ---- Format helpers ----
  static double deflection(double mmValue) =>
      isMetric ? mmValue * MM_TO_CM : mmValue;

  static double evd(double mnm2Value) =>
      isMetric ? mnm2Value * MNM2_TO_KGFCM2 : mnm2Value;

  static double velocity(double msValue) =>
      isMetric ? msValue * MS_TO_CMS : msValue;

  static String deflectionUnit() => isMetric ? 'cm' : 'mm';
  static String evdUnit() => isMetric ? 'kgf/cm²' : 'MN/m²';
  static String velocityUnit() => isMetric ? 'cm/s' : 'm/s';

  // ---- Format with conversion + unit ----
  static String formatDeflection(double mmValue, {int decimals = 4}) {
    return '${deflection(mmValue).toStringAsFixed(decimals)} ${deflectionUnit()}';
  }

  static String formatEVD(double mnm2Value, {int decimals = 2}) {
    return '${evd(mnm2Value).toStringAsFixed(decimals)} ${evdUnit()}';
  }

  static String formatVelocity(double msValue, {int decimals = 4}) {
    return '${velocity(msValue).toStringAsFixed(decimals)} ${velocityUnit()}';
  }

  // ---- Convert raw values (for CSV exports) ----
  static double deflectionConverted(double mm) => deflection(mm);
  static double evdConverted(double mnm2) => evd(mnm2);
  static double velocityConverted(double ms) => velocity(ms);
}