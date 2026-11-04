import 'package:shared_preferences/shared_preferences.dart';
import 'quran_repository.dart';

/// Where the reader left off. One bookmark, persisted on the device — the
/// point is "take me back to where I stopped", not a list of favourites.
class BookmarkStore {
  static const _key = 'mushaf_bookmark';

  static Future<AyahRef?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return AyahRef.parse(prefs.getString(_key));
  }

  static Future<void> save(AyahRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ref.key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
