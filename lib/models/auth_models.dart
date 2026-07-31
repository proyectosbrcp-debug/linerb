import 'user_profile.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  disabled,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final String? message;

  const AuthState({required this.status, this.profile, this.message});

  const AuthState.initial() : this(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    String? message,
    bool clearProfile = false,
    bool clearMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearProfile ? null : profile ?? this.profile,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}
