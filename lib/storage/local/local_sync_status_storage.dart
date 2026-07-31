import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/sync_status_snapshot.dart';
import '../sync_status_storage.dart';
import 'linerb_database.dart';

class LocalSyncStatusStorage implements SyncStatusStorage {
  static const String key = 'sync_status_snapshot_v1';

  final LinerbDatabase database;

  const LocalSyncStatusStorage({required this.database});

  @override
  Future<SyncStatusSnapshot?> restore() async {
    final db = await database.open();
    final rows = await db.query(
      'migration_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.single['value'] as String?;
    if (value == null || value.isEmpty) return null;

    final json = jsonDecode(value) as Map<String, Object?>;
    final phase = _phase(json['phase'] as String?);
    return SyncStatusSnapshot(
      phase: phase == SyncPhase.syncing ? SyncPhase.transientFailure : phase,
      lastSuccessfulSyncAt: _date(json['last_successful_sync_at']),
      lastAttemptAt: _date(json['last_attempt_at']),
      pendingCount: _int(json['pending_count']),
      failedCount: _int(json['failed_count']),
      conflictCount: _int(json['conflict_count']),
      retryScheduledAt: _date(json['retry_scheduled_at']),
      connectivityAvailable: json['connectivity_available'] != false,
      authenticated: json['authenticated'] == true,
      profileActive: json['profile_active'] == true,
      canPush: json['can_push'] == true,
      canPull: json['can_pull'] == true,
      lastErrorCategory: _category(json['last_error_category'] as String?),
      lastErrorAt: _date(json['last_error_at']),
      trigger: _trigger(json['trigger'] as String?),
    );
  }

  @override
  Future<void> save(SyncStatusSnapshot snapshot) async {
    final db = await database.open();
    final json = {
      'phase': snapshot.phase.name,
      'last_successful_sync_at': snapshot.lastSuccessfulSyncAt
          ?.toIso8601String(),
      'last_attempt_at': snapshot.lastAttemptAt?.toIso8601String(),
      'pending_count': snapshot.pendingCount,
      'failed_count': snapshot.failedCount,
      'conflict_count': snapshot.conflictCount,
      'retry_scheduled_at': snapshot.retryScheduledAt?.toIso8601String(),
      'connectivity_available': snapshot.connectivityAvailable,
      'authenticated': snapshot.authenticated,
      'profile_active': snapshot.profileActive,
      'can_push': snapshot.canPush,
      'can_pull': snapshot.canPull,
      'last_error_category': snapshot.lastErrorCategory?.name,
      'last_error_at': snapshot.lastErrorAt?.toIso8601String(),
      'trigger': snapshot.trigger?.name,
    };

    await db.insert('migration_metadata', {
      'key': key,
      'value': jsonEncode(json),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  SyncPhase _phase(String? value) {
    return SyncPhase.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SyncPhase.idle,
    );
  }

  SyncErrorCategory? _category(String? value) {
    if (value == null) return null;
    return SyncErrorCategory.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SyncErrorCategory.unknown,
    );
  }

  SyncTrigger? _trigger(String? value) {
    if (value == null) return null;
    return SyncTrigger.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SyncTrigger.appStart,
    );
  }

  DateTime? _date(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  int _int(Object? value) {
    if (value is int) return value;
    return 0;
  }
}
