/// Capability cells from ARCHITECTURE.md. Update only with dated evidence.
enum CapabilityState {
  verified,
  partial,
  unverified,
  outOfScope,
}

/// Platform ids used for matrix lookups (release gates).
enum MatrixPlatform {
  android,
  ios,
  windows,
  linux,
  macos,
}

/// BLE discovery/control is allowed only when the matrix cell is verified or
/// partial. All platforms start unverified (OM-011 / ARCHITECTURE.md).
class CapabilityMatrix {
  const CapabilityMatrix();

  /// Mirrors ARCHITECTURE.md row "BLE discovery/control".
  CapabilityState bleDiscovery(MatrixPlatform platform) {
    return CapabilityState.unverified;
  }

  bool allowsBleControl(MatrixPlatform platform) {
    final state = bleDiscovery(platform);
    return state == CapabilityState.verified ||
        state == CapabilityState.partial;
  }
}

MatrixPlatform? matrixPlatformFromHost(String hostPlatform) {
  return switch (hostPlatform) {
    'android' => MatrixPlatform.android,
    'ios' => MatrixPlatform.ios,
    'windows' => MatrixPlatform.windows,
    'linux' => MatrixPlatform.linux,
    'macos' => MatrixPlatform.macos,
    _ => null,
  };
}
