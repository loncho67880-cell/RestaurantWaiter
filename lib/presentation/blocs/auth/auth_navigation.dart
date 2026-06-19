import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/customer.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';

String resolveLocaleCode(String? preferredLanguage) {
  if (preferredLanguage == 'en') return 'en';
  return 'es';
}

Future<void> applyCustomerLocale(BuildContext context, Customer customer) {
  return context
      .read<AppConfigCubit>()
      .loadConfiguration(locale: resolveLocaleCode(customer.preferredLanguage));
}

/// Waiters do not go through the customer profile-completion flow; once the
/// backend authenticates the waiter account we go straight to the waiter home
/// (active reservations).
Future<void> navigateAfterAuth(BuildContext context, Customer customer) async {
  await applyCustomerLocale(context, customer);
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, '/home');
}
