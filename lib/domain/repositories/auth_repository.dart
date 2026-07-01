import 'package:restaurantwaiter/domain/models/auth_sign_in_result.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';

abstract class AuthRepository {
  Future<AuthSignInResult> signInWithGoogle();

  Future<Waiter> selectRestaurant(String restaurantId);

  Future<void> signOut();
}
