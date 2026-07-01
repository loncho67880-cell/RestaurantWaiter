import 'package:restaurantwaiter/domain/models/waiter.dart';
import 'package:restaurantwaiter/domain/models/waiter_restaurant.dart';

sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Waiter waiter;
  final List<WaiterRestaurant> restaurants;

  AuthAuthenticated(this.waiter, {required this.restaurants});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  AuthError(this.message);
}
