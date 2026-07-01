import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:restaurantwaiter/core/auth/auth_token_provider.dart';
import 'package:restaurantwaiter/domain/exceptions/waiter_not_registered_exception.dart';
import 'package:restaurantwaiter/domain/models/waiter.dart';
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
      final result = await authRepository.signInWithGoogle();
      emit(AuthAuthenticated(
        result.waiter,
        restaurants: result.restaurants,
      ));
    } on WaiterNotRegisteredException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('$e'));
    }
  }

  Future<Waiter> bindRestaurant(String restaurantId) async {
    final state = this.state;
    if (state is! AuthAuthenticated) {
      throw StateError('Cannot bind restaurant when user is not authenticated.');
    }

    final waiter = await authRepository.selectRestaurant(restaurantId);
    emit(AuthAuthenticated(waiter, restaurants: state.restaurants));
    return waiter;
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    emit(AuthInitial());
  }
}
