import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../l10n/app_strings_en.dart';
import '../l10n/app_strings_bn.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _langKey = 'selected_language';
  
  AppStrings _strings = AppStringsEn();
  String _currentLocale = 'en';

  AppStrings get strings => _strings;
  String get currentLocale => _currentLocale;
  bool get isBangla => _currentLocale == 'bn';

  LanguageProvider() {
    _loadSelectedLanguage();
  }

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_langKey) ?? 'en';
    _setLanguageInternal(lang);
  }

  void _setLanguageInternal(String lang) {
    _currentLocale = lang;
    if (lang == 'bn') {
      _strings = AppStringsBn();
    } else {
      _strings = AppStringsEn();
    }
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLocale == lang) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
    _setLanguageInternal(lang);
  }
}
