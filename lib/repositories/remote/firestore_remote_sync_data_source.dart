import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/sync_models.dart';
import '../sync_repository.dart';
import 'finding_remote_mapper.dart';
import 'inspection_remote_mapper.dart';

class FirestoreRemoteSyncDataSource implements RemoteSyncDataSource {
  final FirebaseFirestore firestore;
  final InspectionRemoteMapper inspectionMapper;
  final FindingRemoteMapper findingMapper;

  const FirestoreRemoteSyncDataSource({
    required this.firestore,
    this.inspectionMapper = const InspectionRemoteMapper(),
    this.findingMapper = const FindingRemoteMapper(),
  });

  @override
  Future<void> push(SyncQueueEntry operation) async {
    final payload = _decode(operation.payloadJson);

    switch ((operation.entityType, operation.operation)) {
      case (SyncEntityType.inspection, SyncOperationType.create):
        return createInspection(payload);
      case (SyncEntityType.inspection, SyncOperationType.update):
        return updateInspection(payload);
      case (SyncEntityType.inspection, SyncOperationType.delete):
        return deleteInspection(payload);
      case (SyncEntityType.finding, SyncOperationType.create):
        return createFinding(payload);
      case (SyncEntityType.finding, SyncOperationType.update):
        return updateFinding(payload);
      case (SyncEntityType.finding, SyncOperationType.delete):
        return deleteFinding(payload);
    }
  }

  @override
  Future<void> pushBatch(List<SyncQueueEntry> operations) async {
    final batch = firestore.batch();
    for (final operation in operations) {
      _addToBatch(batch, operation);
    }
    await batch.commit();
  }

  @override
  Future<void> createInspection(Map<String, Object?> payload) async {
    final remote = inspectionMapper.fromLocalPayload(payload);
    await _inspectionRef(remote['global_id'] as String).set(remote);
  }

  @override
  Future<void> updateInspection(Map<String, Object?> payload) async {
    final remote = inspectionMapper.fromLocalPayload(payload);
    await _inspectionRef(
      remote['global_id'] as String,
    ).set(remote, SetOptions(merge: true));
  }

  @override
  Future<void> deleteInspection(Map<String, Object?> payload) async {
    final remote = inspectionMapper.fromLocalPayload(payload);
    await _inspectionRef(remote['global_id'] as String).set({
      'global_id': remote['global_id'],
      'deleted_at': remote['deleted_at'] ?? Timestamp.now(),
      'updated_at': remote['updated_at'] ?? Timestamp.now(),
      'remote_version': remote['remote_version'],
    }, SetOptions(merge: true));
  }

  @override
  Future<void> createFinding(Map<String, Object?> payload) async {
    final remote = findingMapper.fromLocalPayload(payload);
    await _findingRef(
      remote['inspection_global_id'] as String,
      remote['global_id'] as String,
    ).set(remote);
  }

  @override
  Future<void> updateFinding(Map<String, Object?> payload) async {
    final remote = findingMapper.fromLocalPayload(payload);
    await _findingRef(
      remote['inspection_global_id'] as String,
      remote['global_id'] as String,
    ).set(remote, SetOptions(merge: true));
  }

  @override
  Future<void> deleteFinding(Map<String, Object?> payload) async {
    final remote = findingMapper.fromLocalPayload(payload);
    await _findingRef(
      remote['inspection_global_id'] as String,
      remote['global_id'] as String,
    ).set({
      'global_id': remote['global_id'],
      'inspection_global_id': remote['inspection_global_id'],
      'deleted_at': remote['deleted_at'] ?? Timestamp.now(),
      'updated_at': remote['updated_at'] ?? Timestamp.now(),
      'remote_version': remote['remote_version'],
    }, SetOptions(merge: true));
  }

  @override
  Future<RemoteChangeSet> fetchChanges({DateTime? since}) async {
    Query<Map<String, dynamic>> query = firestore.collection('inspections');
    if (since != null) {
      query = query.where(
        'updated_at',
        isGreaterThan: Timestamp.fromDate(since),
      );
    }
    final snapshot = await query.get();
    final inspections = <Map<String, Object?>>[];
    var cursor = since;

    for (final doc in snapshot.docs) {
      final mapped = inspectionMapper.fromRemote(doc.data());
      if (mapped == null) continue;
      inspections.add(mapped);
      final updatedAt = mapped['updated_at'];
      if (updatedAt is Timestamp) {
        final date = updatedAt.toDate();
        if (cursor == null || date.isAfter(cursor)) cursor = date;
      }
    }

    final findings = await fetchFindingsForInspections(
      inspections.map((item) => item['global_id']).whereType<String>().toList(),
    );

    return RemoteChangeSet(
      inspections: inspections,
      findings: findings,
      cursor: cursor,
    );
  }

  @override
  Future<List<Map<String, Object?>>> fetchFindingsForInspections(
    List<String> inspectionGlobalIds,
  ) async {
    final findings = <Map<String, Object?>>[];
    for (final inspectionId in inspectionGlobalIds) {
      final snapshot = await _inspectionRef(
        inspectionId,
      ).collection('findings').get();
      for (final doc in snapshot.docs) {
        final mapped = findingMapper.fromRemote(doc.data());
        if (mapped != null) findings.add(mapped);
      }
    }
    return findings;
  }

  void _addToBatch(WriteBatch batch, SyncQueueEntry operation) {
    final payload = _decode(operation.payloadJson);
    if (operation.entityType == SyncEntityType.inspection) {
      final remote = inspectionMapper.fromLocalPayload(payload);
      batch.set(
        _inspectionRef(remote['global_id'] as String),
        remote,
        SetOptions(merge: operation.operation != SyncOperationType.create),
      );
      return;
    }

    final remote = findingMapper.fromLocalPayload(payload);
    batch.set(
      _findingRef(
        remote['inspection_global_id'] as String,
        remote['global_id'] as String,
      ),
      remote,
      SetOptions(merge: operation.operation != SyncOperationType.create),
    );
  }

  DocumentReference<Map<String, dynamic>> _inspectionRef(String globalId) {
    return firestore.collection('inspections').doc(globalId);
  }

  DocumentReference<Map<String, dynamic>> _findingRef(
    String inspectionGlobalId,
    String findingGlobalId,
  ) {
    return _inspectionRef(
      inspectionGlobalId,
    ).collection('findings').doc(findingGlobalId);
  }

  Map<String, Object?> _decode(String payloadJson) {
    return Map<String, Object?>.from(jsonDecode(payloadJson) as Map);
  }
}
