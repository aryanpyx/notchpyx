/// Static facts about this build.
///
/// Kept as constants rather than read from the package metadata at runtime:
/// the alternative is a plugin and an async call for two strings that are fixed
/// at compile time. Keep [version] in step with `pubspec.yaml`.
class AppInfo {
  const AppInfo._();

  static const String name = 'DynamicBar';
  static const String version = '0.1.0';

  static const String tagline = 'A Dynamic Island for Windows 11.';

  /// Third party code in the shipped binary. There is deliberately very little
  /// of it: the application takes no runtime package dependencies, so this is
  /// the framework and the platform, and nothing else.
  static const List<({String name, String licence})> licences =
      <({String name, String licence})>[
        (name: 'Flutter', licence: 'BSD 3-Clause'),
        (name: 'Dart SDK', licence: 'BSD 3-Clause'),
        (name: 'Material Icons', licence: 'Apache 2.0'),
      ];
}
