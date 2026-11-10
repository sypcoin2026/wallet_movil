import 'package:shared_preferences/shared_preferences.dart';
import '../domain/sypc_watch_book.dart';

/// Convenience persistence for PUBLIC watch-only metadata only.
/// SharedPreferences is not a vault and must NEVER store secrets.
class SypcWatchStore {
  static const String key = 'sypc_watch_book_v1';
  const SypcWatchStore._();

  static Future<SypcWatchBook> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const SypcWatchBook();
    return SypcWatchBook.decode(raw);
  }

  static Future<void> save(SypcWatchBook book) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(key, book.encode());
    if (!ok) throw StateError('No se guardaron los datos locales.');
  }
}
