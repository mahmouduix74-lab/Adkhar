import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'utils/nav.dart';

/// Design tokens. [AppColors] resolves against whichever theme is active,
/// so screens never have to ask which mode they are in — they just read
/// `AppColors.surface` and get white in light mode, near-black in dark.
///
/// The static getters read from [AppColors.of], which the app sets once per
/// build in main.dart. That keeps every existing `AppColors.x` call site
/// working while still supporting a runtime theme switch.
class AppPalette {
  final Color paper;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color gold;
  final Color goldSoft;
  final Color green;

  const AppPalette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.gold,
    required this.goldSoft,
    required this.green,
  });

  /// The page is a soft grey and the cards are pure white. A white page
  /// with white cards made the two read as one flat surface; the tint is
  /// what gives the cards an edge without needing a border on every one.
  static const light = AppPalette(
    paper: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF181512),
    ink2: Color(0xFF5D554B),
    ink3: Color(0xFF9C9389),
    line: Color(0xFFE9E5DF),
    gold: Color(0xFFC2913A),
    goldSoft: Color(0x1AC2913A),
    green: Color(0xFF5B8F6D),
  );

  static const dark = AppPalette(
    paper: Color(0xFF0E0E10),
    surface: Color(0xFF1B1B1E),
    ink: Color(0xFFF2EFEA),
    ink2: Color(0xFFBDB6AC),
    ink3: Color(0xFF8A8279),
    line: Color(0xFF32302D),
    gold: Color(0xFFD9AC57),
    goldSoft: Color(0x26D9AC57),
    green: Color(0xFF77AE8B),
  );
}

/// Ambient palette. Set once per build by the root widget.
class AppColors {
  static AppPalette _active = AppPalette.light;

  static void use(AppPalette palette) => _active = palette;

  static Color get paper => _active.paper;
  static Color get surface => _active.surface;
  static Color get ink => _active.ink;
  static Color get ink2 => _active.ink2;
  static Color get ink3 => _active.ink3;
  static Color get line => _active.line;
  static Color get gold => _active.gold;
  static Color get goldSoft => _active.goldSoft;
  static Color get green => _active.green;
}

const double kCardRadius = 20;

/// Arabic body font for UI chrome (buttons, labels, nav).
TextStyle uiFont({double? size, FontWeight? weight, Color? color, double? height}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color, height: height);

/// Amiri for recited text only (dhikr, Quran) — never for UI chrome.
TextStyle quranFont({double? size, FontWeight? weight, Color? color, double? height}) =>
    GoogleFonts.amiri(fontSize: size, fontWeight: weight, color: color, height: height);

/// Builds the ThemeData for one brightness.
///
/// Deliberately does **not** touch [AppColors]. MaterialApp evaluates both
/// `theme:` and `darkTheme:` on every build, so setting the ambient palette
/// here left it on whichever was constructed last — the app rendered a dark
/// card on a light page. Only MaterialApp's `builder` sets the palette, once
/// per build, after the brightness is actually known.
ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: palette.paper,
    colorScheme: ColorScheme.fromSeed(seedColor: palette.gold, brightness: brightness).copyWith(
      surface: palette.surface,
    ),
    dividerColor: palette.line,
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
        .apply(bodyColor: palette.ink, displayColor: palette.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.paper,
      foregroundColor: palette.ink,
      elevation: 0,
    ),
    iconTheme: IconThemeData(color: palette.ink),
    useMaterial3: true,
    // One calm fade-through for every route, including the ones Flutter
    // builds itself (predictive back, deep links).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: AppPageTransitions(),
      TargetPlatform.android: AppPageTransitions(),
      TargetPlatform.macOS: AppPageTransitions(),
    }),
  );
}

/// The chevron that means "onward", and the arrow that means "send".
///
/// Deliberately NOT chosen by reading direction. Material's directional
/// glyphs are declared with `matchTextDirection: true`, so Flutter already
/// mirrors them in an RTL layout: `chevron_right_rounded` renders pointing
/// left in Arabic on its own. Picking the left-pointing glyph by hand as
/// well flips it a second time and lands back pointing right, which is the
/// bug these constants exist to stop anyone re-introducing.
///
/// The rule: use these, and never wrap them in a pinned `Directionality`.
/// The heading at the top of a page — the app-bar title, or its equivalent
/// on the screens that draw their own header. One size everywhere; the old
/// spread from 14 to 20 made some pages look like sub-sections of others.
TextStyle pageTitle({Color? color}) =>
    uiFont(size: 22, weight: FontWeight.w700, color: color ?? AppColors.ink);

const IconData forwardChevron = Icons.chevron_right_rounded;
const IconData forwardArrow = Icons.arrow_forward_rounded;
