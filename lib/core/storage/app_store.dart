import 'package:shared_preferences/shared_preferences.dart';

class StoreKeys {
  StoreKeys._();

  static const settings = 'lw.settings.v1';
  static const leaveTypes = 'lw.leaveTypes.v1';
  static const leaveEntries = 'lw.leaveEntries.v1';
  static const customHolidays = 'lw.customHolidays.v1';
  static const plans = 'lw.plans.v1';
}

/// Thin wrapper over SharedPreferences. All user data lives on the device.
class AppStore {
  AppStore(this._prefs);

  final SharedPreferences _prefs;

  String? read(String key) => _prefs.getString(key);

  Future<void> write(String key, String value) => _prefs.setString(key, value);

  /// Removes every LeaveWise key.
  Future<void> clearAll() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith('lw.')).toList()) {
      await _prefs.remove(key);
    }
  }
}
