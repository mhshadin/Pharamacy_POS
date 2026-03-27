import '../l10n/app_strings.dart';

class MedTypeUnits {
  static Map<String, String?> getLabels(String? medType, AppStrings l10n) {
    if (medType == null) {
      return {'unit1': l10n.boxes, 'unit2': l10n.strips, 'unit3': l10n.pieces};
    }

    switch (medType.toLowerCase()) {
      case 'tablet':
      case 'capsule':
        return {'unit1': l10n.boxes, 'unit2': l10n.strips, 'unit3': l10n.pieces};
      case 'syrup':
      case 'suspension':
      case 'liquid':
        return {'unit1': null, 'unit2': l10n.bottle, 'unit3': l10n.ml};
      case 'injection':
      case 'injectable':
      case 'vial':
      case 'ampoule':
        return {'unit1': l10n.boxes, 'unit2': l10n.vial, 'unit3': null};
      case 'cream':
      case 'ointment':
      case 'gel':
        return {'unit1': null, 'unit2': l10n.tube, 'unit3': l10n.grams};
      case 'drops':
      case 'eye drops':
      case 'ear drops':
        return {'unit1': null, 'unit2': l10n.bottle, 'unit3': l10n.ml};
      case 'inhaler':
      case 'spray':
        return {'unit1': l10n.boxes, 'unit2': l10n.inhaler, 'unit3': null};
      case 'powder':
      case 'sachet':
        return {'unit1': l10n.boxes, 'unit2': l10n.sachet, 'unit3': null};
      case 'suppository':
        return {'unit1': l10n.boxes, 'unit2': l10n.pieces, 'unit3': null};
      case 'patch':
        return {'unit1': l10n.boxes, 'unit2': l10n.patch, 'unit3': null};
      default:
        return {'unit1': l10n.boxes, 'unit2': l10n.unit, 'unit3': null};
    }
  }

  static bool hasUnit1(String? medType) {
    if (medType == null) return true;
    switch (medType.toLowerCase()) {
      case 'syrup':
      case 'suspension':
      case 'liquid':
      case 'cream':
      case 'ointment':
      case 'gel':
      case 'drops':
      case 'eye drops':
      case 'ear drops':
        return false;
      default:
        return true;
    }
  }

  static bool hasUnit3(String? medType) {
    if (medType == null) return true;
    switch (medType.toLowerCase()) {
      case 'tablet':
      case 'capsule':
      case 'syrup':
      case 'suspension':
      case 'liquid':
      case 'cream':
      case 'ointment':
      case 'gel':
      case 'drops':
      case 'eye drops':
      case 'ear drops':
        return true;
      default:
        return false;
    }
  }
}
