import 'api_client.dart';
import 'api_config.dart';
import '../../features/auth/data/repositories/api_auth_repository.dart';

class ApiServices {
  ApiServices(ApiAuthRepository auth)
    : auth = _client(ApiConfig.authBaseUrl, auth),
      branches = _client(ApiConfig.branchBaseUrl, auth),
      attendance = _client(ApiConfig.attendanceBaseUrl, auth);

  final ApiClient auth;
  final ApiClient branches;
  final ApiClient attendance;

  static ApiClient _client(String baseUrl, ApiAuthRepository auth) => ApiClient(
    baseUrl: baseUrl,
    accessToken: auth.getAccessToken,
    refreshSession: auth.refreshNow,
  );
}
