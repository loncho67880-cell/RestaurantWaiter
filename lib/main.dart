import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/auth/auth_token_provider.dart';
import 'package:restaurantwaiter/core/config/app_settings.dart';
import 'package:restaurantwaiter/core/network/dio_client.dart';
import 'package:restaurantwaiter/domain/repositories/app_config_repository.dart';
import 'package:restaurantwaiter/domain/repositories/branch_repository.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_qr_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_session_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/app_config_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/table_session_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/auth_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/branch_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/order_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/reservation_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/table_layout_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/table_qr_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/services/google_auth_service.dart';
import 'package:restaurantwaiter/infrastructure/services/table_session_realtime_service.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/theme_restaurant.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/login_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/branch_selection/branch_selection_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/restaurant_selection/restaurant_selection_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/manual_order/manual_order_screen.dart';
import 'package:restaurantwaiter/presentation/shell/main_shell.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  final appSettings = await AppSettings.load();
  final authTokenHolder = AuthTokenHolder();

  final dio = createDioClient(
    appSettings.apiBaseUrl,
    tokenProvider: authTokenHolder,
  );
  await warmUpApiConnection(dio);

  final authRepository = AuthRepositoryImpl(
    dio: dio,
    googleAuthService: GoogleAuthService(),
  );
  final appConfigRepository = AppConfigRepositoryImpl(dio: dio);
  final menuRepository = MenuRepository(dio: dio);
  final branchRepository = BranchRepositoryImpl(dio: dio);
  final reservationRepository = ReservationRepositoryImpl(dio: dio);
  final orderRepository = OrderRepositoryImpl(dio: dio);
  final tableLayoutRepository = TableLayoutRepositoryImpl(dio: dio);
  final tableQrRepository = TableQrRepositoryImpl(dio: dio);
  final tableSessionRepository = TableSessionRepositoryImpl(dio: dio);
  final tableSessionRealtimeService = TableSessionRealtimeService(
    apiBaseUrl: appSettings.apiBaseUrl,
  );

  runApp(
    MyApp(
      appSettings: appSettings,
      authTokenHolder: authTokenHolder,
      authRepository: authRepository,
      appConfigRepository: appConfigRepository,
      menuRepository: menuRepository,
      branchRepository: branchRepository,
      reservationRepository: reservationRepository,
      orderRepository: orderRepository,
      tableLayoutRepository: tableLayoutRepository,
      tableQrRepository: tableQrRepository,
      tableSessionRepository: tableSessionRepository,
      tableSessionRealtimeService: tableSessionRealtimeService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppSettings appSettings;
  final AuthTokenHolder authTokenHolder;
  final AuthRepositoryImpl authRepository;
  final AppConfigRepository appConfigRepository;
  final MenuRepository menuRepository;
  final BranchRepository branchRepository;
  final ReservationRepository reservationRepository;
  final OrderRepository orderRepository;
  final TableLayoutRepository tableLayoutRepository;
  final TableQrRepository tableQrRepository;
  final TableSessionRepository tableSessionRepository;
  final TableSessionRealtimeService tableSessionRealtimeService;

  const MyApp({
    super.key,
    required this.appSettings,
    required this.authTokenHolder,
    required this.authRepository,
    required this.appConfigRepository,
    required this.menuRepository,
    required this.branchRepository,
    required this.reservationRepository,
    required this.orderRepository,
    required this.tableLayoutRepository,
    required this.tableQrRepository,
    required this.tableSessionRepository,
    required this.tableSessionRealtimeService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: menuRepository),
        RepositoryProvider<BranchRepository>.value(value: branchRepository),
        RepositoryProvider<ReservationRepository>.value(
          value: reservationRepository,
        ),
        RepositoryProvider<OrderRepository>.value(value: orderRepository),
        RepositoryProvider<TableLayoutRepository>.value(
          value: tableLayoutRepository,
        ),
        RepositoryProvider<TableQrRepository>.value(value: tableQrRepository),
        RepositoryProvider<TableSessionRepository>.value(
          value: tableSessionRepository,
        ),
        RepositoryProvider<TableSessionRealtimeService>.value(
          value: tableSessionRealtimeService,
        ),
        RepositoryProvider<AppConfigRepository>.value(
          value: appConfigRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppConfigCubit(
              appConfigRepository: appConfigRepository,
            )..loadBootstrap(),
          ),
          BlocProvider(
            create: (_) => AuthCubit(
              authRepository,
              tokenHolder: authTokenHolder,
            ),
          ),
        ],
        child: BlocBuilder<AppConfigCubit, AppConfigState>(
          builder: (context, appConfigState) {
            if (appConfigState.isLoading &&
                appConfigState.localizedStrings.isEmpty) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final colorScheme = appConfigState.themeData.colorScheme;
            final configCubit = context.read<AppConfigCubit>();
            final currentTheme = RestaurantTheme(
              name: appConfigState.restaurantName.isNotEmpty
                  ? appConfigState.restaurantName
                  : configCubit.translate('appName'),
              primary: colorScheme.primary,
              background: appConfigState.themeData.scaffoldBackgroundColor,
              surface: colorScheme.surface,
              onPrimary: colorScheme.onPrimary,
              onBackground: colorScheme.onSurface,
            );

            return MaterialApp(
              navigatorKey: appNavigatorKey,
              title: currentTheme.name,
              debugShowCheckedModeBanner: false,
              theme: appConfigState.themeData,
              home: LoginScreen(themeData: currentTheme),
              routes: {
                '/login': (context) => LoginScreen(themeData: currentTheme),
                '/restaurant-select': (context) =>
                    const RestaurantSelectionScreen(),
                '/branch-select': (context) => const BranchSelectionScreen(),
                '/home': (context) => const MainShell(),
                '/manual-order': (context) => const ManualOrderScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

