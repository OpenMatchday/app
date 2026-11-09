/// Media-plane mediums allowed by protocol MediaMedium and AC-1.3.
/// Cellular and BLE are refused.
const Set<String> allowedMediaMediums = {'wifi', 'ethernet'};

const Set<String> refusedMediaMediums = {
  'cellular',
  'ble',
  'bluetooth',
  'bt',
};

bool isAllowedMediaMedium(String medium) {
  return allowedMediaMediums.contains(medium);
}

/// Returns null when allowed; otherwise a refusal reason for UI / logs.
String? mediaMediumRefusalReason(String medium) {
  if (isAllowedMediaMedium(medium)) {
    return null;
  }
  return 'Media streams use Wi-Fi or Ethernet only; refused medium="$medium"';
}

class MediaMediumRefused implements Exception {
  MediaMediumRefused(this.medium)
      : message = mediaMediumRefusalReason(medium) ??
            'Media medium refused: $medium';

  final String medium;
  final String message;

  @override
  String toString() => message;
}
