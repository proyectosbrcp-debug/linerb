import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sync_status_snapshot.dart';

class SyncErrorClassifier {
  const SyncErrorClassifier();

  SyncErrorCategory classify(Object error) {
    if (error is TimeoutException) return SyncErrorCategory.timeout;
    if (error is SocketException) return SyncErrorCategory.network;
    if (error is FormatException || error is ArgumentError) {
      return SyncErrorCategory.invalidData;
    }
    if (error is FirebaseException) {
      return _fromFirebaseCode(error.code);
    }

    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied')) return SyncErrorCategory.permission;
    if (text.contains('unauthenticated')) {
      return SyncErrorCategory.authentication;
    }
    if (text.contains('unavailable')) return SyncErrorCategory.unavailable;
    if (text.contains('deadline') || text.contains('timeout')) {
      return SyncErrorCategory.timeout;
    }
    if (text.contains('network') || text.contains('socket')) {
      return SyncErrorCategory.network;
    }
    if (text.contains('invalid')) return SyncErrorCategory.invalidData;
    if (text.contains('conflict')) return SyncErrorCategory.conflict;
    return SyncErrorCategory.unknown;
  }

  String friendlyMessage(SyncErrorCategory category) {
    return switch (category) {
      SyncErrorCategory.network =>
        'Sin conexión. Los datos permanecen guardados en el dispositivo.',
      SyncErrorCategory.unavailable =>
        'El servicio remoto no está disponible. Se volverá a intentar automáticamente.',
      SyncErrorCategory.timeout =>
        'La sincronización tardó demasiado. Se volverá a intentar automáticamente.',
      SyncErrorCategory.authentication => 'La sesión debe renovarse.',
      SyncErrorCategory.permission =>
        'No tienes permiso para enviar estos cambios.',
      SyncErrorCategory.invalidData =>
        'Algunos datos requieren revisión antes de sincronizarse.',
      SyncErrorCategory.conflict => 'Existe un conflicto pendiente.',
      SyncErrorCategory.localStorage =>
        'No fue posible leer o escribir datos locales.',
      SyncErrorCategory.remoteStorage =>
        'No fue posible guardar los cambios en el servicio remoto.',
      SyncErrorCategory.rateLimited =>
        'Hay demasiados intentos. Se reintentará más tarde.',
      SyncErrorCategory.unknown => 'Algunos datos no pudieron sincronizarse.',
    };
  }

  bool isTransient(SyncErrorCategory category) {
    return switch (category) {
      SyncErrorCategory.network ||
      SyncErrorCategory.unavailable ||
      SyncErrorCategory.timeout ||
      SyncErrorCategory.remoteStorage ||
      SyncErrorCategory.rateLimited ||
      SyncErrorCategory.unknown => true,
      SyncErrorCategory.authentication ||
      SyncErrorCategory.permission ||
      SyncErrorCategory.invalidData ||
      SyncErrorCategory.conflict ||
      SyncErrorCategory.localStorage => false,
    };
  }

  SyncErrorCategory _fromFirebaseCode(String code) {
    return switch (code) {
      'permission-denied' => SyncErrorCategory.permission,
      'unauthenticated' => SyncErrorCategory.authentication,
      'unavailable' => SyncErrorCategory.unavailable,
      'deadline-exceeded' => SyncErrorCategory.timeout,
      'resource-exhausted' => SyncErrorCategory.rateLimited,
      'invalid-argument' ||
      'failed-precondition' => SyncErrorCategory.invalidData,
      'aborted' => SyncErrorCategory.conflict,
      'cancelled' => SyncErrorCategory.unavailable,
      _ => SyncErrorCategory.remoteStorage,
    };
  }
}
