import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/capability_matrix.dart';
import 'package:open_matchday/pairing/control_medium.dart';
import 'package:open_matchday/pairing/pairing_session.dart';
import 'package:open_matchday/roles.dart';

void main() {
  late PairingSession session;
  var id = 0;

  setUp(() {
    id = 0;
    session = PairingSession(
      sessionId: 'sess-1',
      directorDeviceId: 'dir-1',
      idFactory: () {
        id += 1;
        return 'id-$id';
      },
    );
  });

  test('QR and manual IP offers are always available', () {
    final qr = session.createOffer(
      controlMedium: ControlMedium.qr,
      host: '192.168.1.10',
      port: 7400,
    );
    final manual = session.createOffer(
      controlMedium: ControlMedium.manualIp,
      host: '10.0.0.2',
      port: 7400,
    );
    expect(qr.controlMedium, ControlMedium.qr);
    expect(manual.controlMedium, ControlMedium.manualIp);
    expect(qr.toSharePayload(), contains('"control_medium":"qr"'));
  });

  test('BLE offer creation is rejected (offer schema qr/manual only)', () {
    expect(
      () => session.createOffer(
        controlMedium: ControlMedium.ble,
        host: '192.168.1.10',
        port: 7400,
      ),
      throwsA(isA<PairingRejectException>()),
    );
  });

  test('BLE discovery is blocked while matrix is unverified', () {
    final outcome = session.startBleDiscovery(MatrixPlatform.windows);
    expect(outcome.status.name, 'blocked');
    expect(session.allowsControlMedium(ControlMedium.ble, MatrixPlatform.android),
        isFalse);
  });

  test('device is not in session until director approves', () {
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'cam-1',
      deviceLabel: 'Camera A',
      requestedRoles: const [ProductionRole.camera],
      controlMedium: ControlMedium.manualIp,
      mediaMedium: 'wifi',
    );
    final ack = session.receiveRequest(
      request,
      platform: MatrixPlatform.windows,
    );
    expect(ack, PairingAckStatus.pendingApproval);
    expect(session.isInSession('cam-1'), isFalse);

    final member = session.approve(
      requestId: 'req-1',
      platform: MatrixPlatform.windows,
    );
    expect(member.approvedByDirector, isTrue);
    expect(session.isInSession('cam-1'), isTrue);
  });

  test('release builds reject unverified role combinations on approve', () {
    final releaseSession = PairingSession(
      sessionId: 'sess-release',
      directorDeviceId: 'dir-1',
      releaseBuild: true,
      idFactory: () => 'id-release-1',
    );
    releaseSession.receiveRequest(
      PairingRequest(
        requestId: 'req-combo',
        deviceId: 'combo-1',
        deviceLabel: 'Combo device',
        requestedRoles: const [
          ProductionRole.camera,
          ProductionRole.scoreboardReader,
        ],
        controlMedium: ControlMedium.manualIp,
        mediaMedium: 'wifi',
      ),
      platform: MatrixPlatform.windows,
    );
    expect(
      () => releaseSession.approve(
        requestId: 'req-combo',
        platform: MatrixPlatform.windows,
      ),
      throwsA(isA<PairingRejectException>()),
    );
    expect(releaseSession.isInSession('combo-1'), isFalse);
  });

  test('non-release builds may approve unverified combinations for measurement',
      () {
    final debugSession = PairingSession(
      sessionId: 'sess-debug',
      directorDeviceId: 'dir-1',
      releaseBuild: false,
      idFactory: () => 'id-debug-1',
    );
    debugSession.receiveRequest(
      PairingRequest(
        requestId: 'req-combo-debug',
        deviceId: 'combo-debug',
        deviceLabel: 'Combo debug',
        requestedRoles: const [
          ProductionRole.camera,
          ProductionRole.eventOperator,
        ],
        controlMedium: ControlMedium.manualIp,
        mediaMedium: 'ethernet',
      ),
      platform: MatrixPlatform.android,
    );
    final member = debugSession.approve(
      requestId: 'req-combo-debug',
      platform: MatrixPlatform.android,
    );
    expect(member.roles, hasLength(2));
    expect(debugSession.isInSession('combo-debug'), isTrue);
  });

  test('cellular and ble media mediums are refused on request', () {
    expect(
      () => session.receiveRequest(
        PairingRequest(
          requestId: 'req-cell',
          deviceId: 'cam-2',
          deviceLabel: 'Cam',
          requestedRoles: const [ProductionRole.camera],
          controlMedium: ControlMedium.qr,
          mediaMedium: 'cellular',
        ),
        platform: MatrixPlatform.windows,
      ),
      throwsA(isA<PairingRejectException>()),
    );
    expect(
      () => session.receiveRequest(
        PairingRequest(
          requestId: 'req-ble',
          deviceId: 'cam-3',
          deviceLabel: 'Cam',
          requestedRoles: const [ProductionRole.camera],
          controlMedium: ControlMedium.qr,
          mediaMedium: 'ble',
        ),
        platform: MatrixPlatform.windows,
      ),
      throwsA(isA<PairingRejectException>()),
    );
  });

  test('BLE control request refused when matrix unverified', () {
    expect(
      () => session.receiveRequest(
        PairingRequest(
          requestId: 'req-ble-ctrl',
          deviceId: 'cam-4',
          deviceLabel: 'Cam',
          requestedRoles: const [ProductionRole.camera],
          controlMedium: ControlMedium.ble,
          mediaMedium: 'wifi',
        ),
        platform: MatrixPlatform.android,
      ),
      throwsA(isA<PairingRejectException>()),
    );
  });
}
