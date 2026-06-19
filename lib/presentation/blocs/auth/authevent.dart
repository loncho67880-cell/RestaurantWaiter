import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/models/customer_profile_data.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit(this.authRepository) : super(AuthInitial());

  Future<void> signInWithGoogle() async {
    try {
      emit(AuthLoading());
      final customer = await authRepository.signInWithGoogle();
      emit(AuthAuthenticated(customer));
    } catch (e, stack) {
      debugPrint('ERROR: $e');
      debugPrint('$stack');
      emit(AuthError('$e'));
    }
  }

  Future<String?> completeProfile(CustomerProfileData profile) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return 'No hay una sesión activa.';

    final previousCustomer = currentState.customer;

    try {
      emit(AuthLoading());
      final customer = await authRepository.updateProfile(
        previousCustomer,
        profile,
      );
      final customerWithLanguage = customer.preferredLanguage == null
          ? customer.copyWith(preferredLanguage: profile.preferredLanguage)
          : customer;
      emit(AuthAuthenticated(customerWithLanguage));
      return null;
    } catch (e, stack) {
      debugPrint('ERROR: $e');
      debugPrint('$stack');
      emit(AuthAuthenticated(previousCustomer));
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    emit(AuthInitial());
  }
}
