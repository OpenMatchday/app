import 'package:flutter/services.dart';

import 'director/audio.dart';
import 'director/source_health.dart';
import 'pairing/media_medium.dart';

/// Bridge to native media modules (sibling `media` repo policy + platform stubs).
///
/// Production path (D1): Flutter UI talks to `media` via MethodChannel /
/// EventChannel for session control, and `dart:ffi` for frame/buffer paths.
///
/// OCR (D5): Scoreboard Reader recognition runs in `media` (Tesseract +
/// tessdata_fast eng, provisional).
class MediaBridge {
  MediaBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('open_matchday/media');

  final MethodChannel _channel;

  /// Invokes the platform media stub. Returns a map with platform + stamp.
  Future<MediaCallbackResult> pingMedia() async {
    final Object? raw = await _channel.invokeMethod<Object?>('ping');
    if (raw is! Map) {
      throw StateError('media ping returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final platform = map['platform']?.toString() ?? 'unknown';
    final stamp = map['stamp']?.toString() ?? '';
    return MediaCallbackResult(platform: platform, stamp: stamp);
  }

  /// Starts media transport only on Wi-Fi or Ethernet (AC-1.3).
  /// Refuses cellular and BLE before the native call.
  Future<MediaStartResult> startMedia({required String medium}) async {
    final refusal = mediaMediumRefusalReason(medium);
    if (refusal != null) {
      throw MediaMediumRefused(medium);
    }
    final Object? raw = await _channel.invokeMethod<Object?>(
      'startMedia',
      <String, Object>{'medium': medium},
    );
    if (raw is! Map) {
      throw StateError('startMedia returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    final platform = map['platform']?.toString() ?? 'unknown';
    final resolved = map['medium']?.toString() ?? medium;
    if (!ok) {
      final error = map['error']?.toString() ?? 'startMedia refused';
      throw PlatformException(code: 'media_medium_refused', message: error);
    }
    return MediaStartResult(platform: platform, medium: resolved);
  }

  /// Starts one-camera Preview path on Wi-Fi/Ethernet (OM-013 / AC-2.1).
  Future<PreviewStartResult> startPreview({
    required String medium,
    String sourceId = 'cam-1',
  }) async {
    final refusal = mediaMediumRefusalReason(medium);
    if (refusal != null) {
      throw MediaMediumRefused(medium);
    }
    final Object? raw = await _channel.invokeMethod<Object?>(
      'startPreview',
      <String, Object>{
        'medium': medium,
        'sourceId': sourceId,
        'bus': 'preview',
      },
    );
    if (raw is! Map) {
      throw StateError('startPreview returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'startPreview refused';
      throw PlatformException(code: 'preview_refused', message: error);
    }
    return PreviewStartResult(
      platform: map['platform']?.toString() ?? 'unknown',
      medium: map['medium']?.toString() ?? medium,
      sourceId: map['sourceId']?.toString() ?? sourceId,
      message: map['message']?.toString() ?? 'Preview receiving',
      snapshotPath: map['snapshotPath']?.toString() ?? '',
    );
  }

  Future<void> stopPreview() async {
    await _channel.invokeMethod<Object?>('stopPreview');
  }

  /// Selects the director audio source independently of video (AC-2.4).
  Future<AudioSelectResult> selectAudioSource({
    required String sourceId,
    String? videoProgramSourceId,
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'selectAudioSource',
      <String, Object?>{
        'sourceId': sourceId,
        'videoProgramSourceId': videoProgramSourceId,
        'followsVideo': false,
      },
    );
    if (raw is! Map) {
      throw StateError('selectAudioSource returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'selectAudioSource refused';
      throw PlatformException(code: 'audio_refused', message: error);
    }
    return AudioSelectResult(
      platform: map['platform']?.toString() ?? 'unknown',
      sourceId: map['sourceId']?.toString() ?? sourceId,
      followsVideo: map['followsVideo'] == true,
      label: map['label']?.toString() ?? sourceId,
    );
  }

  /// Reads peak/RMS meters for the selected audio path (AC-2.5).
  Future<AudioMeters> readAudioMeters({String sourceId = ''}) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'readAudioMeters',
      <String, Object>{'sourceId': sourceId},
    );
    if (raw is! Map) {
      throw StateError('readAudioMeters returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'readAudioMeters refused';
      throw PlatformException(code: 'audio_meter_refused', message: error);
    }
    return AudioMeters(
      peakDb: _asDouble(map['peakDb']),
      rmsDb: _asDouble(map['rmsDb']),
      sourceId: map['sourceId']?.toString() ?? sourceId,
    );
  }

  /// Propagates an explicit Cut/Take to the media plane (AC-2.2 / G3).
  Future<CutTakeBridgeResult> cutTake({
    required String action,
    required String previewSourceId,
    required String programSourceId,
    String previousProgramSourceId = '',
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'cutTake',
      <String, Object>{
        'action': action,
        'previewSourceId': previewSourceId,
        'programSourceId': programSourceId,
        'previousProgramSourceId': previousProgramSourceId,
        'autoSwitch': false,
      },
    );
    if (raw is! Map) {
      throw StateError('cutTake returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'cutTake refused';
      throw PlatformException(code: 'cut_take_refused', message: error);
    }
    return CutTakeBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      action: map['action']?.toString() ?? action,
      previewSourceId: map['previewSourceId']?.toString() ?? previewSourceId,
      programSourceId: map['programSourceId']?.toString() ?? programSourceId,
      previousProgramSourceId:
          map['previousProgramSourceId']?.toString() ?? previousProgramSourceId,
      issuedAtMs: _asInt(map['issuedAtMs']) ?? 0,
      appliedAtMs: _asInt(map['appliedAtMs']) ?? 0,
    );
  }

  /// Sets on-air tally for a camera source (AC-2.3).
  Future<TallyBridgeResult> setTally({
    required String sourceId,
    required bool onAir,
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'setTally',
      <String, Object>{
        'sourceId': sourceId,
        'onAir': onAir,
      },
    );
    if (raw is! Map) {
      throw StateError('setTally returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'setTally refused';
      throw PlatformException(code: 'tally_refused', message: error);
    }
    return TallyBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      sourceId: map['sourceId']?.toString() ?? sourceId,
      onAir: map['onAir'] == true,
    );
  }

  /// Reads A/V sync offset (audio minus video, ms). Live values from media G5.
  Future<AvSyncBridgeResult> readAvSync() async {
    final Object? raw = await _channel.invokeMethod<Object?>('readAvSync');
    if (raw is! Map) {
      throw StateError('readAvSync returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'readAvSync refused';
      throw PlatformException(code: 'av_sync_refused', message: error);
    }
    return AvSyncBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      offsetMs: _asDouble(map['offsetMs']) ?? 0,
      measuredAtMs: _asInt(map['measuredAtMs']) ?? 0,
      correctionMs: _asDouble(map['correctionMs']) ?? 0,
    );
  }

  /// Applies drift correction in milliseconds (AC-2.6 / G5).
  Future<AvSyncBridgeResult> applyDriftCorrection({
    required double correctionMs,
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'applyDriftCorrection',
      <String, Object>{'correctionMs': correctionMs},
    );
    if (raw is! Map) {
      throw StateError('applyDriftCorrection returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'applyDriftCorrection refused';
      throw PlatformException(code: 'drift_refused', message: error);
    }
    return AvSyncBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      offsetMs: _asDouble(map['offsetMs']) ?? 0,
      measuredAtMs: _asInt(map['measuredAtMs']) ?? 0,
      correctionMs: _asDouble(map['correctionMs']) ?? correctionMs,
      residualMs: _asDouble(map['residualMs']),
    );
  }

  /// Reads per-source connection health (AC-2.8).
  Future<SourceHealthBridgeResult> readSourceHealth() async {
    final Object? raw = await _channel.invokeMethod<Object?>('readSourceHealth');
    if (raw is! Map) {
      throw StateError('readSourceHealth returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'readSourceHealth refused';
      throw PlatformException(code: 'health_refused', message: error);
    }
    final sourcesRaw = map['sources'];
    final sources = <SourceHealthEntry>[];
    if (sourcesRaw is List) {
      for (final item in sourcesRaw) {
        if (item is! Map) {
          continue;
        }
        final entry = Map<Object?, Object?>.from(item);
        final stateName = entry['state']?.toString() ?? 'lost';
        final state = SourceHealthState.values.firstWhere(
          (value) => value.name == stateName,
          orElse: () => SourceHealthState.lost,
        );
        sources.add(
          SourceHealthEntry(
            sourceId: entry['sourceId']?.toString() ?? '',
            state: state,
            observedAtMs: _asInt(entry['observedAtMs']) ?? 0,
            detail: entry['detail']?.toString() ?? '',
          ),
        );
      }
    }
    final fallbackRaw = map['programFallback']?.toString() ?? 'last_frame_freeze';
    return SourceHealthBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      sources: sources,
      programFallback: ProgramFallbackModeWire.parse(fallbackRaw),
      sessionAlive: map['sessionAlive'] != false,
    );
  }

  /// Sets recording/streaming intent on the media plane (pre-OM-032/033 stubs).
  Future<OutputIntentBridgeResult> setOutputIntents({
    required bool recording,
    required bool streaming,
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'setOutputIntents',
      <String, Object>{
        'recording': recording,
        'streaming': streaming,
      },
    );
    if (raw is! Map) {
      throw StateError('setOutputIntents returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'setOutputIntents refused';
      throw PlatformException(code: 'output_intent_refused', message: error);
    }
    return OutputIntentBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      recording: map['recording'] == true,
      streaming: map['streaming'] == true,
    );
  }

  /// Reads current output intents from the media plane.
  Future<OutputIntentBridgeResult> readOutputIntents() async {
    final Object? raw = await _channel.invokeMethod<Object?>('readOutputIntents');
    if (raw is! Map) {
      throw StateError('readOutputIntents returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'readOutputIntents refused';
      throw PlatformException(code: 'output_intent_refused', message: error);
    }
    return OutputIntentBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      recording: map['recording'] == true,
      streaming: map['streaming'] == true,
    );
  }

  /// After director crash recovery: force recording/streaming stopped (AC-5.6).
  Future<OutputIntentBridgeResult> recoverOutputsStopped() async {
    final Object? raw =
        await _channel.invokeMethod<Object?>('recoverOutputsStopped');
    if (raw is! Map) {
      throw StateError(
        'recoverOutputsStopped returned unexpected payload: $raw',
      );
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error =
          map['error']?.toString() ?? 'recoverOutputsStopped refused';
      throw PlatformException(code: 'crash_recover_refused', message: error);
    }
    return OutputIntentBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      recording: map['recording'] == true,
      streaming: map['streaming'] == true,
      message: map['message']?.toString() ?? '',
    );
  }

  /// Freezes the Scoreboard Reader preview for four-corner calibration (AC-4.1).
  Future<CalibrationFreezeResult> freezeCalibrationFrame({
    String sourceId = 'scoreboard-1',
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'freezeCalibrationFrame',
      <String, Object>{'sourceId': sourceId},
    );
    if (raw is! Map) {
      throw StateError(
        'freezeCalibrationFrame returned unexpected payload: $raw',
      );
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error =
          map['error']?.toString() ?? 'freezeCalibrationFrame refused';
      throw PlatformException(code: 'calibration_freeze_refused', message: error);
    }
    return CalibrationFreezeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      sourceId: map['sourceId']?.toString() ?? sourceId,
      freezeId: map['freezeId']?.toString() ?? '',
      width: _asDouble(map['width']) ?? 0,
      height: _asDouble(map['height']) ?? 0,
      snapshotPath: map['snapshotPath']?.toString() ?? '',
    );
  }

  /// Probes camera-move MAD against the freeze fingerprint (AC-4.7).
  Future<CameraMoveProbeResult> probeCameraMove({
    String sourceId = 'scoreboard-1',
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'probeCameraMove',
      <String, Object>{'sourceId': sourceId},
    );
    if (raw is! Map) {
      throw StateError('probeCameraMove returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'probeCameraMove refused';
      throw PlatformException(code: 'camera_move_probe_refused', message: error);
    }
    return CameraMoveProbeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      sourceId: map['sourceId']?.toString() ?? sourceId,
      moved: map['moved'] == true,
      mad: _asDouble(map['mad']) ?? 0,
      threshold: _asDouble(map['threshold']) ?? 0,
      message: map['message']?.toString() ?? '',
    );
  }

  /// Reads one calibrated OCR region from media (AC-5.2).
  Future<OcrRegionBridgeResult> readOcrRegion({
    required String fieldId,
    String sourceId = 'scoreboard-1',
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'readOcrRegion',
      <String, Object>{
        'sourceId': sourceId,
        'fieldId': fieldId,
      },
    );
    if (raw is! Map) {
      throw StateError('readOcrRegion returned unexpected payload: $raw');
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error = map['error']?.toString() ?? 'readOcrRegion refused';
      throw PlatformException(code: 'ocr_region_refused', message: error);
    }
    return OcrRegionBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      fieldId: map['fieldId']?.toString() ?? fieldId,
      value: map['value'] ?? '',
      confidence: _asDouble(map['confidence']) ?? 0,
      capturedAt: map['capturedAt']?.toString() ?? '',
      stale: map['stale'] == true,
      rawText: map['rawText']?.toString() ?? '',
      confidenceSignal: map['confidenceSignal']?.toString() ?? '',
    );
  }

  /// Applies configured Program safe state on source loss (AC-2.7).
  Future<SourceLossBridgeResult> applySourceLossFallback({
    required String lostSourceId,
    required String programSourceId,
    required String programFallback,
    String alternateSourceId = '',
  }) async {
    final Object? raw = await _channel.invokeMethod<Object?>(
      'applySourceLossFallback',
      <String, Object>{
        'lostSourceId': lostSourceId,
        'programSourceId': programSourceId,
        'programFallback': programFallback,
        'alternateSourceId': alternateSourceId,
      },
    );
    if (raw is! Map) {
      throw StateError(
        'applySourceLossFallback returned unexpected payload: $raw',
      );
    }
    final map = Map<Object?, Object?>.from(raw);
    final ok = map['ok'] == true;
    if (!ok) {
      final error =
          map['error']?.toString() ?? 'applySourceLossFallback refused';
      throw PlatformException(code: 'source_loss_refused', message: error);
    }
    return SourceLossBridgeResult(
      platform: map['platform']?.toString() ?? 'unknown',
      lostSourceId: map['lostSourceId']?.toString() ?? lostSourceId,
      programSafeState: map['programSafeState']?.toString() ?? programFallback,
      programSourceId: map['programSourceId']?.toString() ?? programSourceId,
      sessionAlive: map['sessionAlive'] != false,
      observedAtMs: _asInt(map['observedAtMs']) ?? 0,
      message: map['message']?.toString() ?? '',
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class AudioSelectResult {
  const AudioSelectResult({
    required this.platform,
    required this.sourceId,
    required this.followsVideo,
    required this.label,
  });

  final String platform;
  final String sourceId;
  final bool followsVideo;
  final String label;
}

class MediaCallbackResult {
  const MediaCallbackResult({required this.platform, required this.stamp});

  final String platform;
  final String stamp;
}

class MediaStartResult {
  const MediaStartResult({required this.platform, required this.medium});

  final String platform;
  final String medium;
}

class PreviewStartResult {
  const PreviewStartResult({
    required this.platform,
    required this.medium,
    required this.sourceId,
    required this.message,
    this.snapshotPath = '',
  });

  final String platform;
  final String medium;
  final String sourceId;
  final String message;
  final String snapshotPath;
}

class CutTakeBridgeResult {
  const CutTakeBridgeResult({
    required this.platform,
    required this.action,
    required this.previewSourceId,
    required this.programSourceId,
    required this.previousProgramSourceId,
    required this.issuedAtMs,
    required this.appliedAtMs,
  });

  final String platform;
  final String action;
  final String previewSourceId;
  final String programSourceId;
  final String previousProgramSourceId;
  final int issuedAtMs;
  final int appliedAtMs;

  int get cutLatencyMs => appliedAtMs - issuedAtMs;
}

class TallyBridgeResult {
  const TallyBridgeResult({
    required this.platform,
    required this.sourceId,
    required this.onAir,
  });

  final String platform;
  final String sourceId;
  final bool onAir;
}

class AvSyncBridgeResult {
  const AvSyncBridgeResult({
    required this.platform,
    required this.offsetMs,
    required this.measuredAtMs,
    required this.correctionMs,
    this.residualMs,
  });

  final String platform;
  final double offsetMs;
  final int measuredAtMs;
  final double correctionMs;
  final double? residualMs;
}

class SourceHealthBridgeResult {
  const SourceHealthBridgeResult({
    required this.platform,
    required this.sources,
    required this.programFallback,
    required this.sessionAlive,
  });

  final String platform;
  final List<SourceHealthEntry> sources;
  final ProgramFallbackMode programFallback;
  final bool sessionAlive;
}

class SourceLossBridgeResult {
  const SourceLossBridgeResult({
    required this.platform,
    required this.lostSourceId,
    required this.programSafeState,
    required this.programSourceId,
    required this.sessionAlive,
    required this.observedAtMs,
    this.message = '',
  });

  final String platform;
  final String lostSourceId;
  final String programSafeState;
  final String programSourceId;
  final bool sessionAlive;
  final int observedAtMs;
  final String message;
}

class OutputIntentBridgeResult {
  const OutputIntentBridgeResult({
    required this.platform,
    required this.recording,
    required this.streaming,
    this.message = '',
  });

  final String platform;
  final bool recording;
  final bool streaming;
  final String message;
}

class CalibrationFreezeResult {
  const CalibrationFreezeResult({
    required this.platform,
    required this.sourceId,
    required this.freezeId,
    required this.width,
    required this.height,
    this.snapshotPath = '',
  });

  final String platform;
  final String sourceId;
  final String freezeId;
  final double width;
  final double height;
  final String snapshotPath;
}

class CameraMoveProbeResult {
  const CameraMoveProbeResult({
    required this.platform,
    required this.sourceId,
    required this.moved,
    required this.mad,
    required this.threshold,
    this.message = '',
  });

  final String platform;
  final String sourceId;
  final bool moved;
  final double mad;
  final double threshold;
  final String message;
}

class OcrRegionBridgeResult {
  const OcrRegionBridgeResult({
    required this.platform,
    required this.fieldId,
    required this.value,
    required this.confidence,
    required this.capturedAt,
    required this.stale,
    this.rawText = '',
    this.confidenceSignal = '',
  });

  final String platform;
  final String fieldId;
  final Object value;
  final double confidence;
  final String capturedAt;
  final bool stale;
  final String rawText;
  final String confidenceSignal;
}
