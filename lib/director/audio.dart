// Independent director audio path (AC-2.4 / AC-2.5).
// Audio selection must not follow Preview/Program video; meters expose peak/RMS.

class AudioSourceOption {
  const AudioSourceOption({
    required this.id,
    required this.label,
    this.deviceName = '',
  });

  final String id;
  final String label;
  final String deviceName;
}

class AudioMeters {
  const AudioMeters({
    this.peakDb,
    this.rmsDb,
    this.sourceId = '',
  });

  final double? peakDb;
  final double? rmsDb;
  final String sourceId;

  bool get hasLevels => peakDb != null || rmsDb != null;
}

class DirectorAudio {
  DirectorAudio({
    List<AudioSourceOption>? sources,
    this.selectedSourceId = '',
    this.meters = const AudioMeters(),
  }) : sources = sources ??
            const [
              AudioSourceOption(id: 'aud-1', label: 'Mic / line 1'),
              AudioSourceOption(id: 'aud-2', label: 'Mic / line 2'),
              AudioSourceOption(id: 'aud-silence', label: 'Silence'),
            ];

  List<AudioSourceOption> sources;
  String selectedSourceId;
  AudioMeters meters;

  /// True when a source is chosen without binding it to a camera id.
  bool get hasIndependentSelection => selectedSourceId.isNotEmpty;

  AudioSourceOption? get selectedSource {
    for (final source in sources) {
      if (source.id == selectedSourceId) {
        return source;
      }
    }
    return null;
  }

  void selectSource(String sourceId) {
    selectedSourceId = sourceId;
  }
}
