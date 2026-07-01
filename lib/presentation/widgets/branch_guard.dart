import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';

/// Redirects to restaurant or branch selection when not configured yet.
class BranchGuard extends StatelessWidget {
  final Widget child;

  const BranchGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>().state;
    final restaurantId = config.restaurantId.trim();
    final branchId = config.branchId.trim();

    if (restaurantId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/restaurant-select');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (branchId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/branch-select');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return child;
  }
}
