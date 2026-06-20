import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';

String resolveLocaleCode(String? preferredLanguage) {
  if (preferredLanguage == 'en') return 'en';
  return 'es';
}

Future<void> applyWaiterLocale(BuildContext context, Waiter waiter) {
  return context
      .read<AppConfigCubit>()
      .loadConfiguration(locale: resolveLocaleCode(waiter.preferredLanguage));
}

/// Waiters choose a branch after login, then go to active reservations.
Future<void> navigateAfterAuth(BuildContext context, Waiter waiter) async {
  await applyWaiterLocale(context, waiter);
  if (!context.mounted) return;

  final defaultBranchId = waiter.defaultBranchId?.trim();
  if (defaultBranchId != null && defaultBranchId.isNotEmpty) {
    context.read<AppConfigCubit>().selectBranch(
          branchId: defaultBranchId,
          branchName: '',
        );
  }

  Navigator.pushReplacementNamed(context, '/branch-select');
}
