import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/presentation/blocs/app_config/app_config_cubit.dart';

/// Redirects to branch selection when no branch has been chosen yet.
class BranchGuard extends StatelessWidget {
  final Widget child;

  const BranchGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final branchId = context.watch<AppConfigCubit>().state.branchId;
    if (branchId.trim().isEmpty) {
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
