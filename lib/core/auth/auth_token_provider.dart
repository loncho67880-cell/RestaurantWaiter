abstract class AuthTokenProvider {
  String? get token;
}

class AuthTokenHolder implements AuthTokenProvider {
  String? _token;

  @override
  String? get token => _token;

  void update(String? value) => _token = value;
}
