import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:provider/provider.dart';
import 'l10n/strings.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'theme.dart';
import 'utils/arabic_numerals.dart';
import 'screens/splash_screen.dart';

void main() {
  // Arabic month names for the Hijri date on the home screen.
  HijriCalendar.setLocal('ar');
  runApp(const AdhkarApp());
}

class AdhkarApp extends StatelessWidget {
  const AdhkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => SettingsState()..load()),
      ],
      child: Consumer<SettingsState>(
        builder: (context, settings, _) {
          final strings = settings.strings;
          return MaterialApp(
            title: 'الأذكار',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: AppStrings.locales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // The palette is ambient (AppColors reads a static), so it has
            // to be re-pointed on every build before any screen paints.
            builder: (context, child) {
              AppColors.use(settings.isDark(context) ? AppPalette.dark : AppPalette.light);
              useArabicDigits = strings.direction == TextDirection.rtl;
              return Directionality(textDirection: strings.direction, child: child!);
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
