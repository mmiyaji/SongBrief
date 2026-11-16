/// Coarse stages of the library load shown on the startup loading screen.
enum LibraryLoadStage {
  checkingAccess,
  fetchingTracks,
  buildingOverview,
  savingSnapshot,
  loadingHistory,
}

class LibraryLoadProgress {
  const LibraryLoadProgress({
    required this.stage,
    required this.step,
    required this.totalSteps,
    this.trackCount,
  });

  final LibraryLoadStage stage;

  /// 1-based index of [stage] among the stages this load runs.
  final int step;
  final int totalSteps;

  /// Number of tracks being processed, once known.
  final int? trackCount;

  /// Share of stages already finished, used for the progress bar.
  double get completedFraction =>
      totalSteps <= 0 ? 0 : ((step - 1) / totalSteps).clamp(0.0, 1.0);
}

typedef LibraryLoadProgressCallback =
    void Function(LibraryLoadProgress progress);
