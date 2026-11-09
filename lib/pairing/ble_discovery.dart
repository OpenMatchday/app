import '../capability_matrix.dart';
import 'control_medium.dart';

/// BLE control discovery (AC-1.1). Media never uses BLE.
///
/// Platform APIs (cited; not invoked until matrix allows):
/// - Android: BluetoothLeScanner
///   https://developer.android.com/reference/android/bluetooth/le/BluetoothLeScanner
/// - Apple: Core Bluetooth
///   https://developer.apple.com/documentation/corebluetooth
/// - Windows: Bluetooth LE advertisement watcher
///   https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.advertisement
class BleDiscovery {
  BleDiscovery({this._matrix = const CapabilityMatrix()});

  final CapabilityMatrix _matrix;

  BleDiscoveryOutcome start({required MatrixPlatform platform}) {
    if (!_matrix.allowsBleControl(platform)) {
      return BleDiscoveryOutcome.blocked(
        platform: platform,
        state: _matrix.bleDiscovery(platform),
        detail:
            'BLE discovery/control is ${_matrix.bleDiscovery(platform).name} '
            'on ${platform.name}; use QR or manual IP',
      );
    }
    // shortcut: no BLE stack wired until a matrix cell is verified/partial
    return BleDiscoveryOutcome.unavailable(
      platform: platform,
      detail:
          'BLE control allowed by matrix but native scanner not wired yet',
    );
  }

  bool allowsControlMedium(ControlMedium medium, MatrixPlatform platform) {
    if (medium != ControlMedium.ble) {
      return true;
    }
    return _matrix.allowsBleControl(platform);
  }
}

enum BleDiscoveryStatus { started, blocked, unavailable }

class BleDiscoveryOutcome {
  const BleDiscoveryOutcome._({
    required this.status,
    required this.platform,
    this.state,
    required this.detail,
  });

  factory BleDiscoveryOutcome.blocked({
    required MatrixPlatform platform,
    required CapabilityState state,
    required String detail,
  }) {
    return BleDiscoveryOutcome._(
      status: BleDiscoveryStatus.blocked,
      platform: platform,
      state: state,
      detail: detail,
    );
  }

  factory BleDiscoveryOutcome.unavailable({
    required MatrixPlatform platform,
    required String detail,
  }) {
    return BleDiscoveryOutcome._(
      status: BleDiscoveryStatus.unavailable,
      platform: platform,
      detail: detail,
    );
  }

  final BleDiscoveryStatus status;
  final MatrixPlatform platform;
  final CapabilityState? state;
  final String detail;

  bool get isActive => status == BleDiscoveryStatus.started;
}
