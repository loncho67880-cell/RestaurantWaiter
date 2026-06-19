import 'package:restaurantwaiter/domain/models/customer.dart';
import 'package:restaurantwaiter/domain/models/customer_profile_data.dart';

abstract class AuthRepository {
  Future<Customer> signInWithGoogle();

  Future<Customer> updateProfile(
    Customer customer,
    CustomerProfileData profile,
  );

  Future<void> signOut();
}
