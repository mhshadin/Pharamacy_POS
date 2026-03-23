class MedTypeUnits {
  static Map<String, String?> getLabels(String? medType) {
    if (medType == null) {
      return {'unit1': 'BOX', 'unit2': 'STRIP', 'unit3': 'PC'};
    }

    switch (medType.toLowerCase()) {
      case 'tablet':
      case 'capsule':
        return {'unit1': 'BOX', 'unit2': 'STRIP', 'unit3': 'PC'};
      case 'syrup':
      case 'suspension':
      case 'liquid':
        return {'unit1': null, 'unit2': 'BOTTLE', 'unit3': 'ML'};
      case 'injection':
      case 'injectable':
      case 'vial':
      case 'ampoule':
        return {'unit1': 'BOX', 'unit2': 'VIAL', 'unit3': null};
      case 'cream':
      case 'ointment':
      case 'gel':
        return {'unit1': null, 'unit2': 'TUBE', 'unit3': 'G'};
      case 'drops':
      case 'eye drops':
      case 'ear drops':
        return {'unit1': null, 'unit2': 'BOTTLE', 'unit3': 'ML'};
      case 'inhaler':
      case 'spray':
        return {'unit1': 'BOX', 'unit2': 'INHALER', 'unit3': null};
      case 'powder':
      case 'sachet':
        return {'unit1': 'BOX', 'unit2': 'SACHET', 'unit3': null};
      case 'suppository':
        return {'unit1': 'BOX', 'unit2': 'PC', 'unit3': null};
      case 'patch':
        return {'unit1': 'BOX', 'unit2': 'PATCH', 'unit3': null};
      default:
        return {'unit1': 'BOX', 'unit2': 'UNIT', 'unit3': null};
    }
  }

  static bool hasUnit1(String? medType) => getLabels(medType)['unit1'] != null;
  static bool hasUnit3(String? medType) => getLabels(medType)['unit3'] != null;
}
