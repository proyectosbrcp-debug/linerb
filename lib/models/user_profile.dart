import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { administrator, supervisor, inspector, viewer }

UserRole userRoleFromStorage(String value) {
  final normalized = value.trim().toLowerCase();
  return UserRole.values.firstWhere(
    (role) => role.name == normalized,
    orElse: () => UserRole.viewer,
  );
}

String userRoleToStorage(UserRole role) {
  return role.name;
}

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  String get operationalName {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return uid;
  }

  Map<String, Object?> toStorageJson() {
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email,
      'role': userRoleToStorage(role),
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static UserProfile? fromStorageJson(Map<String, Object?> json) {
    final uid = json['uid'];
    final displayName = json['display_name'];
    final email = json['email'];
    final role = json['role'];
    final active = json['active'];
    final createdAt = _dateTimeFromJson(json['created_at']);
    final updatedAt = _dateTimeFromJson(json['updated_at']);

    if (uid is! String || uid.isEmpty) return null;
    if (displayName is! String) return null;
    if (email is! String) return null;
    if (role is! String) return null;
    if (active is! bool) return null;
    if (createdAt == null || updatedAt == null) return null;

    return UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      role: userRoleFromStorage(role),
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static UserProfile? fromFirestore(Map<String, Object?> json) {
    final uid = json['uid'];
    final displayName = json['display_name'];
    final email = json['email'];
    final role = json['role'];
    final active = json['active'];
    final createdAt = _dateTimeFromFirestore(json['created_at']);
    final updatedAt = _dateTimeFromFirestore(json['updated_at']);

    if (uid is! String || uid.isEmpty) return null;
    if (displayName is! String) return null;
    if (email is! String) return null;
    if (role is! String) return null;
    if (active is! bool) return null;
    if (createdAt == null || updatedAt == null) return null;

    return UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      role: userRoleFromStorage(role),
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static DateTime? _dateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    return _dateTimeFromJson(value);
  }
}
