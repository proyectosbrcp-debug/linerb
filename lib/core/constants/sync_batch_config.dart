class SyncBatchConfig {
  const SyncBatchConfig._();

  static const int pushBatchSize = 100;
  static const int pullInspectionsLimit = 250;
  static const int pullFindingsLimit = 250;
  static const int localApplyBatchSize = 250;
}
