import 'package:restaurantwaiter/domain/models/waiter.dart';
import 'package:restaurantwaiter/domain/models/waiter_restaurant.dart';

class AuthSignInResult {
  final Waiter waiter;
  final List<WaiterRestaurant> restaurants;

  const AuthSignInResult({
    required this.waiter,
    required this.restaurants,
  });
}
