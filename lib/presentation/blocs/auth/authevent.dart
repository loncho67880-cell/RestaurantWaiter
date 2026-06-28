import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/auth/auth_token_provider.dart';
import 'package:restaurantwaiter/domain/exceptions/waiter_not_registered_exception.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  final AuthTokenHolder? tokenHolder;

  AuthCubit(this.authRepository, {this.tokenHolder}) : super(AuthInitial());

  void _syncToken(AuthState state) {
    if (tokenHolder == null) return;
    if (state is AuthAuthenticated) {
      tokenHolder!.update(state.waiter.token);
    } else if (state is AuthInitial || state is AuthUnauthenticated) {
      tokenHolder!.update(null);
    }
  }

  @override
  void emit(AuthState state) {
    _syncToken(state);
    super.emit(state);
  }

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
