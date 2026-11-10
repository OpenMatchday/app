import 'package:flutter/services.dart';

import 'director/audio.dart';
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
