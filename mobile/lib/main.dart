import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Navigator global untuk auto-logout fail-closed: sesi invalid /
/// kedaluwarsa / backend tak terjangkau di LAYAR MANA PUN menendang user
/// kembali ke LoginPage. Cermin web: event 'auth:expired' +
/// AuthExpiredListener di App.jsx (termasuk throttle 2 detik).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

DateTime? _lastForceNav;

void _forceLogoutToLogin() {
  final now = DateTime.now();
  if (_lastForceNav != null &&
      now.difference(_lastForceNav!) < const Duration(seconds: 2)) {
    return;
  }
  _lastForceNav = now;
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  ApiService.onSessionExpired = _forceLogoutToLogin;
  runApp(const MyApp());
}

/// Gerbang auth aplikasi (cermin web PrivateRoute di App.jsx):
/// HANYA sesi yang terbukti valid (token + diakui backend) boleh masuk.
/// Token basi, backend mati, timeout, 401/403 → LOGIN PAGE. Fail-closed.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Disimpan sekali agar tidak divalidasi ulang tiap rebuild (ganti tema).
  late final Future<bool> _sessionFuture = ApiService.hasValidSession();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Form4x',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('id')],
          // Parity web: light/dark dari AppTheme (dark = #1a1a2e family).
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
          home: FutureBuilder<bool>(
            future: _sessionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final bool isLoggedIn = snapshot.data ?? false;
              return isLoggedIn ? const HomePage() : const LoginPage();
            },
          ),
        );
      },
    );
  }
}
