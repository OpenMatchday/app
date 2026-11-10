import 'package:flutter/services.dart';

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
