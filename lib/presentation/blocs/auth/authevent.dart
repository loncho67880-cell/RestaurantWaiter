import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/domain/exceptions/waiter_not_registered_exception.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit(this.authRepository) : super(AuthInitial());

  Future<void> signInWithGoogle() async {
    try {
      emit(AuthLoading());
      final waiter = await authRepository.signInWithGoogle();
      emit(AuthAuthenticated(waiter));
    } on WaiterNotRegisteredException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('$e'));
    }
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    emit(AuthInitial());
  }
}
