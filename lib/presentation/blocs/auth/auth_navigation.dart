import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';
import 'package:restaurantwaiter/domain/models/waiter_restaurant.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';

String resolveLocaleCode(String? preferredLanguage) {
  if (preferredLanguage == 'en') return 'en';
  return 'es';
}

Future<void> applyWaiterLocale(BuildContext context, Waiter waiter) {
  return context.read<AppConfigCubit>().loadRemoteConfiguration(
        locale: resolveLocaleCode(waiter.preferredLanguage),
      );
}

Future<void> proceedWithRestaurant(
  BuildContext context, {
  required Waiter waiter,
  required WaiterRestaurant restaurant,
}) async {
  context.read<AppConfigCubit>().selectRestaurant(
        restaurantId: restaurant.id,
        restaurantName: restaurant.name,
      );

  final boundWaiter = await context.read<AuthCubit>().bindRestaurant(
        restaurant.id,
      );
  if (!context.mounted) return;

  await applyWaiterLocale(context, boundWaiter);
  if (!context.mounted) return;

  final configState = context.read<AppConfigCubit>().state;
  if (!configState.hasRemoteConfig) return;

  final defaultBranchId = boundWaiter.defaultBranchId?.trim();
  if (defaultBranchId != null && defaultBranchId.isNotEmpty) {
    context.read<AppConfigCubit>().selectBranch(
          branchId: defaultBranchId,
          branchName: '',
        );
  }

  Navigator.pushReplacementNamed(context, '/branch-select');
}

/// After login: pick restaurant (if needed), then branch selection.
Future<void> navigateAfterAuth(
  BuildContext context,
  Waiter waiter,
  List<WaiterRestaurant> restaurants,
) async {
  if (restaurants.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<AppConfigCubit>().translate('restaurantRequiredError'),
        ),
      ),
    );
    return;
  }

  if (restaurants.length > 1) {
    Navigator.pushReplacementNamed(context, '/restaurant-select');
    return;
  }

  await proceedWithRestaurant(
    context,
    waiter: waiter,
    restaurant: restaurants.first,
  );
}
