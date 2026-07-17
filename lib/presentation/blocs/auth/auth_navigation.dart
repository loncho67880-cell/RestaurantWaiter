import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/branch.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';
import 'package:restaurantwaiter/domain/models/waiter_restaurant.dart';
import 'package:restaurantwaiter/main.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';
import 'package:restaurantwaiter/presentation/blocs/auth/authevent.dart';

/// Clears the navigation stack and opens branch selection (fresh start).
void navigateToBranchSelection(
  BuildContext context, {
  bool clearBranch = true,
}) {
  if (clearBranch) {
    context.read<AppConfigCubit>().clearBranch();
  }
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil('/branch-select', (route) => false);
}

/// Signs out, clears restaurant/branch config, and resets navigation to login.
///
/// Cubits and the root navigator are captured before any await so this still
/// reaches `/login` when the caller's widget (e.g. the drawer) is unmounted.
///
/// Order matters: leave `/home` before clearing restaurantId, otherwise
/// [BranchGuard] briefly redirects to restaurant selection.
Future<void> signOutAndResetToLogin(BuildContext context) async {
  final appConfigCubit = context.read<AppConfigCubit>();
  final authCubit = context.read<AuthCubit>();
  final navigator = appNavigatorKey.currentState;

  await authCubit.signOut();
  navigator?.pushNamedAndRemoveUntil('/login', (route) => false);
  await appConfigCubit.clearRemoteConfiguration();
}

/// After picking a branch: persist selection and reset navigation to home.
void navigateToHomeAfterBranch(BuildContext context, Branch branch) {
  context.read<AppConfigCubit>().selectBranch(
    branchId: branch.id,
    branchName: branch.name,
  );
  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
}

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

  navigateToBranchSelection(context, clearBranch: false);
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
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/restaurant-select', (route) => false);
    return;
  }

  await proceedWithRestaurant(
    context,
    waiter: waiter,
    restaurant: restaurants.first,
  );
}
