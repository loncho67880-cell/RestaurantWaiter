import 'package:restaurantwaiter/domain/models/table_qr_token.dart';

abstract class TableQrRepository {
  Future<List<TableQrToken>> getBranchTokens({
    required String branchId,
    required String accessToken,
  });
}
