import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/barcode_scan_screen.dart';
import 'screens/dish_scan_screen.dart';
import 'screens/result_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/stores_screen.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    DevicePreview(
      // Developer tool only: a release build must render the app itself,
      // not the app inside a simulated phone frame.
      enabled: !kReleaseMode,
      defaultDevice: Devices.ios.iPhone13,
      builder: (context) => const FateenApp(),
    ),
  );
}

class FateenApp extends StatefulWidget {
  const FateenApp({super.key});

  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));

  @override
  State<FateenApp> createState() => _FateenAppState();
}

class _FateenAppState extends State<FateenApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
        valueListenable: FateenApp.locale,
        builder: (context, locale, _) => MaterialApp(
              title: 'فطين',
              debugShowCheckedModeBanner: false,
              locale: locale,
              builder: (context, child) {
                return Directionality(
                  textDirection: locale.languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: DevicePreview.appBuilder(context, child),
                );
              },
              theme: AppTheme.light.copyWith(
                platform: TargetPlatform.iOS,
              ),
              initialRoute: '/splash',
              routes: {
                '/splash': (context) => const SplashScreen(),
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/home': (context) => const HomeScreen(),
                '/search': (context) => const SearchScreen(),
                '/barcode-scan': (context) => const BarcodeScanScreen(),
                '/dish-scan': (context) => const DishScanScreen(),
                '/result': (context) => const ResultScreen(),
                '/favorites': (context) => const FavoritesScreen(),
                '/stores': (context) => const StoresScreen(),
                '/disclaimer': (context) => const DisclaimerScreen(),
                '/profile': (context) => const ProfileScreen(),
                '/edit-profile': (context) => const EditProfileScreen(),
              },
            ));
  }
}
