/// On-air tally for the camera currently on Program (AC-2.3).
class CameraTally {
  const CameraTally({
    required this.cameraSourceId,
    this.programSourceId = '',
  });

  /// This camera device's source id (e.g. cam-1).
  final String cameraSourceId;

  /// Director Program source; empty means nothing on air.
  final String programSourceId;

  bool get isOnAir =>
      programSourceId.isNotEmpty && programSourceId == cameraSourceId;

  CameraTally copyWith({
    String? cameraSourceId,
    String? programSourceId,
  }) {
    return CameraTally(
      cameraSourceId: cameraSourceId ?? this.cameraSourceId,
      programSourceId: programSourceId ?? this.programSourceId,
    );
  }
}
