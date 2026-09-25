/// SINGLE SOURCE OF TRUTH for the app's font.
///
/// This is the only file you need to touch to change the app's font.
///
/// HOW IT WORKS (and why it's safe):
/// - [family] is passed to ThemeData(fontFamily: ...), which cascades to
///   every Text widget in the app automatically — you don't need to edit
///   individual screens.
/// - If the font family named here isn't actually bundled in the app yet
///   (see assets/fonts/README.md for how to add it), Flutter does NOT
///   crash or throw. It silently falls back to the platform default font.
///   This means you can safely change [family] here at any time — the
///   worst case is "still looks like the default font", never a build error.
/// - Once you've added the .ttf files and declared them in pubspec.yaml
///   (see the guide), this same line switches the whole app to the real
///   font instantly.
class AppFonts {
  AppFonts._();

  /// The font family name to use app-wide.
  /// Must exactly match the `family:` value declared in pubspec.yaml's
  /// `fonts:` section once you add real font files.
  static const String family = 'Cairo';

  /// Fallback fonts tried (in order) if [family] isn't available.
  /// Keeping a system Arabic-friendly fallback means the app still looks
  /// reasonable even before you add the Cairo files.
  static const List<String> fallback = [
    'Tahoma', // ships on Android/most platforms, solid Arabic coverage
  ];
}
