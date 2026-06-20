import 'package:restaurantwaiter/domain/models/waiter.dart';

abstract class AuthRepository {
  Future<Waiter> signInWithGoogle();

  Future<void> signOut();
}
