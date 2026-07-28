/// Unit conversion helpers — ported 1:1 from the web app's lib/units.ts.
/// Weight and distance are stored in kg / km. Glucose is stored as mg/dL.

typedef UnitSystem = String; // 'metric' | 'imperial'

double kgToLbs(double kg) => kg * 2.20462;
double lbsToKg(double lbs) => lbs * 0.45359237;
double kmToMiles(double km) => km * 0.621371;
double mgdlToMmol(double mgdl) => mgdl / 18.0182;
double mmolToMgdl(double mmol) => mmol * 18.0182;
double ftInToCm(double ft, double inch) => (ft * 12 + inch) * 2.54;

({int ft, int inch}) cmToFtIn(double cm) {
  final totalIn = cm / 2.54;
  final ft = (totalIn / 12).floor();
  final inch = (totalIn % 12).round();
  return (ft: ft, inch: inch);
}

class Measured {
  final String value;
  final String unit;
  const Measured(this.value, this.unit);
}

Measured formatWeight(double? kg, UnitSystem sys) {
  if (kg == null) return Measured('—', sys == 'imperial' ? 'lbs' : 'kg');
  if (sys == 'imperial') return Measured(kgToLbs(kg).toStringAsFixed(1), 'lbs');
  return Measured(kg.toStringAsFixed(1), 'kg');
}

Measured formatHeight(double? cm, UnitSystem sys) {
  if (cm == null) return Measured('—', sys == 'imperial' ? 'ft' : 'cm');
  if (sys == 'imperial') {
    final r = cmToFtIn(cm);
    return Measured("${r.ft}'${r.inch}\"", '');
  }
  return Measured(cm.toStringAsFixed(0), 'cm');
}

Measured formatGlucose(double? mgdl, UnitSystem sys) {
  if (mgdl == null) return Measured('—', sys == 'imperial' ? 'mg/dL' : 'mmol/L');
  if (sys == 'imperial') return Measured(mgdl.round().toString(), 'mg/dL');
  return Measured(mgdlToMmol(mgdl).toStringAsFixed(1), 'mmol/L');
}

Measured formatDistance(double km, UnitSystem sys) {
  if (sys == 'imperial') return Measured(kmToMiles(km).toStringAsFixed(2), 'miles');
  return Measured(km.toStringAsFixed(2), 'km');
}

String getMetricUnit(String metricType, UnitSystem sys) {
  switch (metricType) {
    case 'weight':
      return sys == 'imperial' ? 'lbs' : 'kg';
    case 'distance':
      return sys == 'imperial' ? 'miles' : 'km';
    case 'glucose':
      return sys == 'imperial' ? 'mg/dL' : 'mmol/L';
    default:
      return '';
  }
}

double toStorageValue(String metricType, double userValue, UnitSystem sys) {
  if (sys == 'metric') {
    if (metricType == 'glucose') return mmolToMgdl(userValue);
    return userValue;
  }
  switch (metricType) {
    case 'weight':
      return lbsToKg(userValue);
    case 'distance':
      return userValue / 0.621371;
    case 'glucose':
      return userValue;
    default:
      return userValue;
  }
}

double toDisplayValue(String metricType, double storedValue, UnitSystem sys) {
  if (sys == 'metric') {
    if (metricType == 'glucose') return mgdlToMmol(storedValue);
    return storedValue;
  }
  switch (metricType) {
    case 'weight':
      return kgToLbs(storedValue);
    case 'distance':
      return kmToMiles(storedValue);
    case 'glucose':
      return storedValue;
    default:
      return storedValue;
  }
}
