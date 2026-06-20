import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

    return Scaffold(
      backgroundColor: themeData.background,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            navigateAfterAuth(context, state.waiter);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

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
                      'Inicia sesión para continuar',
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
                        onPressed: isLoading
                            ? null
                            : () => context.read<AuthCubit>().signInWithGoogle(),
                        child: isLoading
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
                                    'Continuar con Google',
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
                    if (state is AuthError) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE8E6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF5C6C2),
                          ),
                        ),
                        child: Text(
                          _friendlyError(state.message),
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFC5221F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _friendlyError(String message) {
    if (message.contains('cancelado') || message.contains('canceled')) {
      return 'Inicio de sesión cancelado.';
    }
    if (message.contains('registrado como mesero') ||
        message.contains('Contacte al administrador')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message.replaceFirst('Exception: ', '');
  }
}
