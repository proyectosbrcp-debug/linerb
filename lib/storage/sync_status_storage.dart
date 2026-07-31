import '../models/sync_status_snapshot.dart';

abstract class SyncStatusStorage {
  Future<SyncStatusSnapshot?> restore();

  Future<void> save(SyncStatusSnapshot snapshot);
}
