import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/models/branch.dart';
import 'package:restaurantwaiter/domain/repositories/branch_repository.dart';

import 'branch_selection_state.dart';

class BranchSelectionCubit extends Cubit<BranchSelectionState> {
  final BranchRepository branchRepository;
  final String restaurantId;

  BranchSelectionCubit({
    required this.branchRepository,
    required this.restaurantId,
  }) : super(const BranchSelectionState());

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(
      status: BranchSelectionStatus.loading,
      clearError: true,
    ));
    try {
      final branches = await branchRepository.getBranches(
        restaurantId: restaurantId,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: BranchSelectionStatus.loaded,
        branches: branches,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: BranchSelectionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void selectBranch(Branch branch) {
    if (isClosed) return;
    emit(state.copyWith(selectedBranch: branch));
  }
}
