import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/config/app_settings.dart';
import 'package:restaurantwaiter/domain/repositories/branch_repository.dart';
import 'package:restaurantwaiter/domain/repositories/order_repository.dart';
import 'package:restaurantwaiter/domain/repositories/reservation_repository.dart';
import 'package:restaurantwaiter/domain/repositories/table_layout_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/auth_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/branch_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/menu_repository.dart';
import 'package:restaurantwaiter/infrastructure/repositories/order_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/reservation_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/repositories/table_layout_repository_impl.dart';
import 'package:restaurantwaiter/infrastructure/services/google_auth_service.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/theme_restaurant.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/login_screen.dart';
import 'package:restaurantwaiter/presentation/blocs/branch_selection/branch_selection_screen.dart';
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

  final dio = Dio(
    BaseOptions(
      baseUrl: appSettings.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  );

  final authRepository = AuthRepositoryImpl(
    dio: dio,
    googleAuthService: GoogleAuthService(),
    restaurantId: appSettings.restaurantId,
  );
  final menuRepository = MenuRepository(dio: dio);
  final branchRepository = BranchRepositoryImpl(dio: dio);
  final reservationRepository = ReservationRepositoryImpl(dio: dio);
  final orderRepository = OrderRepositoryImpl(dio: dio);
  final tableLayoutRepository = TableLayoutRepositoryImpl(dio: dio);

  runApp(
    MyApp(
      authRepository: authRepository,
      menuRepository: menuRepository,
      branchRepository: branchRepository,
      reservationRepository: reservationRepository,
      orderRepository: orderRepository,
      tableLayoutRepository: tableLayoutRepository,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthRepositoryImpl authRepository;
  final MenuRepository menuRepository;
  final BranchRepository branchRepository;
  final ReservationRepository reservationRepository;
  final OrderRepository orderRepository;
  final TableLayoutRepository tableLayoutRepository;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.menuRepository,
    required this.branchRepository,
    required this.reservationRepository,
    required this.orderRepository,
    required this.tableLayoutRepository,
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AppConfigCubit()..loadConfiguration()),
          BlocProvider(create: (_) => AuthCubit(authRepository)),
        ],
        child: BlocBuilder<AppConfigCubit, AppConfigState>(
          builder: (context, appConfigState) {
            final currentTheme = RestaurantTheme(
              name: appConfigState.restaurantName.isNotEmpty
                  ? appConfigState.restaurantName
                  : 'Kiosco',
              primary: RestaurantTheme.fromHex('#FF5722'),
              background: RestaurantTheme.fromHex('#F5F5F5'),
              surface: RestaurantTheme.fromHex('#FFFFFF'),
              onPrimary: RestaurantTheme.fromHex('#FFFFFF'),
              onBackground: RestaurantTheme.fromHex('#212121'),
            );

            return MaterialApp(
              navigatorKey: appNavigatorKey,
              title: currentTheme.name,
              debugShowCheckedModeBanner: false,
              theme: appConfigState.themeData,
              home: LoginScreen(themeData: currentTheme),
              routes: {
                '/login': (context) => LoginScreen(themeData: currentTheme),
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
