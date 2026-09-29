/// A minimal async key-value store used by craft_kit features that persist
/// data.
///
/// craft_kit does not force a storage plugin on you. Implement this interface
/// on top of `shared_preferences`, `flutter_secure_storage`, Hive or anything
/// else, and pass it to the feature that needs it.
abstract interface class CraftStorage {
  /// Returns the value stored under [key], or `null` if there is none.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any existing value.
  Future<void> write(String key, String value);

  /// Removes the value stored under [key], if any.
  Future<void> remove(String key);
}

/// A [CraftStorage] that keeps data in memory only.
///
/// Useful for tests, previews and as a default. Data is lost when the app
/// process ends.
class MemoryCraftStorage implements CraftStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}
