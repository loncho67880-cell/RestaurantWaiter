class WaiterNotRegisteredException implements Exception {
  final String message;

  const WaiterNotRegisteredException([
    this.message =
        'No está registrado como mesero. Contacte al administrador.',
  ]);

  @override
  String toString() => message;
}
