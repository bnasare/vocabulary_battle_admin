import 'package:cloud_functions/cloud_functions.dart';

/// Centralized Firebase Functions configuration for the admin app.
///
/// This ensures all cloud function calls use the correct region and
/// provides support for emulator configuration during development.
class FirebaseFunctionsConfig {
  // The region where your Firebase Functions are deployed
  static const String _region = 'us-central1';

  // Singleton instance
  static FirebaseFunctions? _instance;

  /// Gets the configured FirebaseFunctions instance.
  ///
  /// All cloud function calls should use this instead of
  /// FirebaseFunctions.instance to ensure correct region configuration.
  static FirebaseFunctions get instance {
    _instance ??= FirebaseFunctions.instanceFor(region: _region);
    return _instance!;
  }

  /// Configures the functions instance to use the local emulator.
  ///
  /// Call this during app initialization when running in development mode.
  ///
  /// Example:
  /// ```dart
  /// if (kDebugMode) {
  ///   FirebaseFunctionsConfig.useEmulator('localhost', 5001);
  /// }
  /// ```
  static void useEmulator(String host, int port) {
    instance.useFunctionsEmulator(host, port);
  }

  /// Resets the instance (useful for testing).
  static void reset() {
    _instance = null;
  }
}
