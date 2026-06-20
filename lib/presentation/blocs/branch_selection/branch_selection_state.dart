import 'package:equatable/equatable.dart';
import 'package:restaurantwaiter/domain/models/branch.dart';

enum BranchSelectionStatus { initial, loading, loaded, error }

class BranchSelectionState extends Equatable {
  final BranchSelectionStatus status;
  final List<Branch> branches;
  final Branch? selectedBranch;
  final String? errorMessage;

  const BranchSelectionState({
    this.status = BranchSelectionStatus.initial,
    this.branches = const [],
    this.selectedBranch,
    this.errorMessage,
  });

  bool get canContinue => selectedBranch != null;

  BranchSelectionState copyWith({
    BranchSelectionStatus? status,
    List<Branch>? branches,
    Branch? selectedBranch,
    bool clearSelectedBranch = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BranchSelectionState(
      status: status ?? this.status,
      branches: branches ?? this.branches,
      selectedBranch:
          clearSelectedBranch ? null : selectedBranch ?? this.selectedBranch,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, branches, selectedBranch, errorMessage];
}
