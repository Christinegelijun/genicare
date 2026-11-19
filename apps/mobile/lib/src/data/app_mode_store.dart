import 'package:shared_preferences/shared_preferences.dart';
import 'package:venicare_app/src/domain/models.dart';

/// Without [SharedPreferences] (tests, first frame) the mode lives in memory only.
class AppModeStore {
  AppModeStore([this._prefs]);

  static const _key = 'app_mode';

  final SharedPreferences? _prefs;

  AppMode read() {
    return AppMode.values.asNameMap()[_prefs?.getString(_key)] ??
        AppMode.family;
  }

  Future<void> write(AppMode mode) async {
    await _prefs?.setString(_key, mode.name);
  }
}
