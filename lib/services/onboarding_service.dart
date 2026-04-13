import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class OnboardingService {
  OnboardingService._();
  static final instance = OnboardingService._();

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.onboardingCompletedPref) ?? false;
  }

  Future<bool> shouldShowOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(AppConstants.onboardingCompletedPref) ?? false;
    if (!completed) return true;
    return prefs.getBool(AppConstants.onboardingShowOnStartupPref) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompletedPref, true);
  }

  Future<void> setShowOnStartup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingShowOnStartupPref, value);
  }

  Future<bool> getShowOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.onboardingShowOnStartupPref) ?? false;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompletedPref, false);
  }
}
