import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'auth.dart';
import 'screens/budgets_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/fixed_expenses_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/transactions_screen.dart';
import 'supabase.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const BudgetApp());
}

class BudgetApp extends StatefulWidget {
  const BudgetApp({super.key});

  @override
  State<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  GoRouter _buildRouter() {
    final notifier = _AuthNotifier();
    return GoRouter(
      refreshListenable: notifier,
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final loggedIn = AuthService.currentUser != null;
        final atLogin = state.matchedLocation == '/login';
        if (!loggedIn) return atLogin ? null : '/login';
        if (atLogin) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ShellScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, state) {
                  final p = state.uri.queryParameters;
                  return TransactionsScreen(
                    initialMonth: p['month'],
                    initialMajor: p['major'],
                    initialSub: p['sub'],
                    initialQ: p['q'],
                    initialFixed: p['fixed'],
                  );
                },
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/budgets',
                builder: (_, _) => const BudgetsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/fixed',
                builder: (_, _) => const FixedExpensesScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/categories',
                builder: (_, _) => const CategoriesScreen(),
              ),
            ]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '가계부',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = AuthService.onAuthStateChange.listen((_) => notifyListeners());
  }
  late final dynamic _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
