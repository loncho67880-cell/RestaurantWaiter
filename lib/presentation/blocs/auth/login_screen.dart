import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/theme_restaurant.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_navigation.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/auth_state.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';

class LoginScreen extends StatelessWidget {
  final RestaurantTheme themeData;

  const LoginScreen({super.key, required this.themeData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final configCubit = context.watch<AppConfigCubit>();
    String t(String key) => configCubit.translate(key);

    return Scaffold(
      backgroundColor: themeData.background,
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) =>
                current is AuthAuthenticated && previous is! AuthAuthenticated,
            listener: (context, state) {
              navigateAfterAuth(context, (state as AuthAuthenticated).waiter);
            },
          ),
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) =>
                current is AuthInitial && previous is AuthAuthenticated,
            listener: (context, state) {
              context.read<AppConfigCubit>().clearRemoteConfiguration();
            },
          ),
        ],
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final authState = state;
            final isAuthLoading = authState is AuthLoading;
            final authenticatedWaiter =
                authState is AuthAuthenticated ? authState.waiter : null;
            final isConfigLoading =
                authenticatedWaiter != null && configCubit.state.isLoading;
            final configError = authenticatedWaiter != null &&
                !configCubit.state.hasRemoteConfig &&
                configCubit.state.errorMessage != null;

            if (isConfigLoading ||
                (authenticatedWaiter != null &&
                    !configCubit.state.hasRemoteConfig &&
                    configCubit.state.errorMessage == null)) {
              return Center(
                child: CircularProgressIndicator(color: themeData.primary),
              );
            }

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: themeData.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 48,
                          color: themeData.primary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        themeData.name,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeData.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('loginSubtitle'),
                        style: textTheme.bodyLarge?.copyWith(
                          color: themeData.onBackground.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeData.surface,
                            foregroundColor: themeData.onBackground,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: themeData.onBackground.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                          ),
                          onPressed: isAuthLoading || configError
                              ? null
                              : () => context
                                  .read<AuthCubit>()
                                  .signInWithGoogle(),
                          child: isAuthLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: themeData.primary,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/google_logo.png',
                                      height: 24,
                                      width: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      t('loginContinueGoogle'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: themeData.onBackground,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (authState is AuthError) ...[
                        const SizedBox(height: 20),
                        _ErrorBanner(
                          message: _friendlyError(authState.message, t),
                          textTheme: textTheme,
                        ),
                      ],
                      if (configError) ...[
                        const SizedBox(height: 20),
                        _ErrorBanner(
                          message: t('appConfigLoadError'),
                          textTheme: textTheme,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => applyWaiterLocale(
                            context,
                            authenticatedWaiter,
                          ),
                          child: Text(t('retry')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _friendlyError(String message, String Function(String) t) {
    if (message.contains('cancelado') || message.contains('canceled')) {
      return t('loginErrorCanceled');
    }
    if (message.contains('registrado como mesero') ||
        message.contains('Contacte al administrador')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message.replaceFirst('Exception: ', '');
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final TextTheme textTheme;

  const _ErrorBanner({
    required this.message,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C6C2)),
      ),
      child: Text(
        message,
        style: textTheme.bodyMedium?.copyWith(color: const Color(0xFFC5221F)),
        textAlign: TextAlign.center,
      ),
    );
  }
}
