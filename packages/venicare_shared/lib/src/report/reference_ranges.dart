/// Home-measurement reference lines. They only mark a reading for the doctor's
/// attention and must never be presented as a diagnosis.
abstract final class ReferenceRanges {
  static const int systolicHigh = 140;
  static const int diastolicHigh = 90;
  static const int heartRateLow = 50;
  static const int heartRateHigh = 100;

  /// Readings carry no fasting/after-meal context, so only the random-glucose
  /// line and the hypoglycaemia line are usable. Unit: mmol/L.
  static const double bloodSugarLow = 3.9;
  static const double bloodSugarHigh = 11.1;
}

bool isPressureAboveReference(int systolic, int diastolic) {
  return systolic >= ReferenceRanges.systolicHigh ||
      diastolic >= ReferenceRanges.diastolicHigh;
}

bool isHeartRateOutOfRange(int heartRate) {
  return heartRate < ReferenceRanges.heartRateLow ||
      heartRate > ReferenceRanges.heartRateHigh;
}

bool isBloodSugarOutOfRange(double bloodSugar) {
  return bloodSugar < ReferenceRanges.bloodSugarLow ||
      bloodSugar >= ReferenceRanges.bloodSugarHigh;
}
