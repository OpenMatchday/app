import 'package:flutter/services.dart';

/// Spike-only bridge to a native media callback.
///
/// Production path (D1): Flutter UI talks to the sibling `media` library via
/// MethodChannel / EventChannel for session control, and `dart:ffi` (or a
/// Flutter plugin wrapping the media ABI) for frame/buffer paths. See
/// docs/spikes/d1-application-framework.md.
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
}

class MediaCallbackResult {
  const MediaCallbackResult({required this.platform, required this.stamp});

  final String platform;
  final String stamp;
}
