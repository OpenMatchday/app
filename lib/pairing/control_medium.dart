/// Control-plane pairing mediums (protocol ControlMedium). Media never uses BLE.
enum ControlMedium {
  ble,
  qr,
  manualIp,
}

extension ControlMediumWire on ControlMedium {
  String get wire => switch (this) {
        ControlMedium.ble => 'ble',
        ControlMedium.qr => 'qr',
        ControlMedium.manualIp => 'manual_ip',
      };

  /// QR and manual IP are always available (AC-1.2).
  bool get isAlwaysAvailable =>
      this == ControlMedium.qr || this == ControlMedium.manualIp;
}

ControlMedium? controlMediumFromWire(String value) {
  return switch (value) {
    'ble' => ControlMedium.ble,
    'qr' => ControlMedium.qr,
    'manual_ip' => ControlMedium.manualIp,
    _ => null,
  };
}
