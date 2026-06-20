import '../models/branch.dart';

abstract class BranchRepository {
  Future<List<Branch>> getBranches({
    required String restaurantId,
  });
}
