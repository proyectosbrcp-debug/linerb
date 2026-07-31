import '../models/user_profile.dart';

class PermissionService {
  const PermissionService();

  bool canCreateInspection(UserProfile profile) {
    return switch (profile.role) {
      UserRole.administrator ||
      UserRole.supervisor ||
      UserRole.inspector => profile.active,
      UserRole.viewer => false,
    };
  }

  bool canUpdateInspection(UserProfile profile) {
    return switch (profile.role) {
      UserRole.administrator || UserRole.supervisor => profile.active,
      UserRole.inspector || UserRole.viewer => false,
    };
  }

  bool canDeleteInspection(UserProfile profile) {
    return profile.active && profile.role == UserRole.administrator;
  }

  bool canViewDashboard(UserProfile profile) {
    return switch (profile.role) {
      UserRole.administrator ||
      UserRole.supervisor ||
      UserRole.viewer => profile.active,
      UserRole.inspector => false,
    };
  }

  bool canViewAllInspections(UserProfile profile) {
    return switch (profile.role) {
      UserRole.administrator ||
      UserRole.supervisor ||
      UserRole.viewer => profile.active,
      UserRole.inspector => false,
    };
  }

  bool canManageUsers(UserProfile profile) {
    return profile.active && profile.role == UserRole.administrator;
  }

  bool canPushSync(UserProfile profile) {
    return switch (profile.role) {
      UserRole.administrator ||
      UserRole.supervisor ||
      UserRole.inspector => profile.active,
      UserRole.viewer => false,
    };
  }

  bool canPullSync(UserProfile profile) {
    return profile.active;
  }

  bool canRunManualSync(UserProfile profile) {
    return profile.active;
  }

  bool canViewAdministrativeSyncDiagnostics(UserProfile profile) {
    return profile.active && profile.role == UserRole.administrator;
  }
}
