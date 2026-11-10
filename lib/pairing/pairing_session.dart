import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;

import '../capability_matrix.dart';
import '../role_assignment.dart';
import '../roles.dart';
import 'ble_discovery.dart';
import 'control_medium.dart';
import 'media_medium.dart';

const String protocolVersion = '0.1.0';

class PairingOffer {
  const PairingOffer({
    required this.offerId,
    required this.directorDeviceId,
    required this.controlMedium,
    required this.host,
    required this.port,
    this.expiresAt,
  });

  final String offerId;
  final String directorDeviceId;
  final ControlMedium controlMedium;
  final String host;
  final int port;
  final DateTime? expiresAt;

  Map<String, Object?> toWirePayload() {
    return {
      'offer_id': offerId,
      'director_device_id': directorDeviceId,
      'control_medium': controlMedium.wire,
      'control_endpoint': {
        'host': host,
        'port': port,
      },
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    };
  }

  /// Text payload for QR encoding / paste join (AC-1.2).
  String toSharePayload() {
    return jsonEncode({
      'protocol_version': protocolVersion,
      'kind': 'pairing.offer',
      'payload': toWirePayload(),
    });
  }
}

class PairingRequest {
  PairingRequest({
    required this.requestId,
    required this.deviceId,
    required this.deviceLabel,
    required this.requestedRoles,
    required this.controlMedium,
    required this.mediaMedium,
    this.offerId,
  });

  final String requestId;
  final String? offerId;
  final String deviceId;
  final String deviceLabel;
  final List<ProductionRole> requestedRoles;
  final ControlMedium controlMedium;
  final String mediaMedium;
}

enum PairingAckStatus { pendingApproval, joined }

class JoinedDevice {
  const JoinedDevice({
    required this.deviceId,
    required this.deviceLabel,
    required this.roles,
    required this.mediaMedium,
    required this.approvedByDirector,
  });

  final String deviceId;
  final String deviceLabel;
  final List<ProductionRole> roles;
  final String mediaMedium;
  final bool approvedByDirector;
}

class PairingRejectException implements Exception {
  PairingRejectException(this.reason, this.message);

  final String reason;
  final String message;

  @override
  String toString() => message;
}

/// Director-side pairing session: offers, pending requests, explicit approve.
class PairingSession {
  PairingSession({
    required this.sessionId,
    required this.directorDeviceId,
    CapabilityMatrix matrix = const CapabilityMatrix(),
    BleDiscovery? bleDiscovery,
    String Function()? idFactory,
    bool? releaseBuild,
  })  : _matrix = matrix,
        _ble = bleDiscovery ?? BleDiscovery(matrix: matrix),
        _nextId = idFactory ?? _defaultIdFactory,
        _releaseBuild = releaseBuild ?? kReleaseMode;

  final String sessionId;
  final String directorDeviceId;
  final CapabilityMatrix _matrix;
  final BleDiscovery _ble;
  final String Function() _nextId;
  final bool _releaseBuild;

  final List<PairingOffer> offers = <PairingOffer>[];
  final List<PairingRequest> pending = <PairingRequest>[];
  final Map<String, JoinedDevice> joined = <String, JoinedDevice>{};

  static int _seq = 0;
  static String _defaultIdFactory() {
    _seq += 1;
    return 'local-$_seq';
  }

  /// QR and manual IP offers are always available (AC-1.2).
  PairingOffer createOffer({
    required ControlMedium controlMedium,
    required String host,
    required int port,
  }) {
    if (!controlMedium.isAlwaysAvailable) {
      throw PairingRejectException(
        'unsupported_medium',
        'pairing.offer allows only qr or manual_ip',
      );
    }
    if (host.trim().isEmpty) {
      throw ArgumentError('host must be non-empty');
    }
    if (port < 1 || port > 65535) {
      throw ArgumentError('port out of range');
    }
    final offer = PairingOffer(
      offerId: _nextId(),
      directorDeviceId: directorDeviceId,
      controlMedium: controlMedium,
      host: host.trim(),
      port: port,
    );
    offers.add(offer);
    return offer;
  }

  BleDiscoveryOutcome startBleDiscovery(MatrixPlatform platform) {
    return _ble.start(platform: platform);
  }

  bool allowsControlMedium(ControlMedium medium, MatrixPlatform platform) {
    return _ble.allowsControlMedium(medium, platform);
  }

  /// Queues a join request. Device is not a session member until [approve].
  PairingAckStatus receiveRequest(
    PairingRequest request, {
    required MatrixPlatform platform,
  }) {
    final mediaRefusal = mediaMediumRefusalReason(request.mediaMedium);
    if (mediaRefusal != null) {
      throw PairingRejectException('unsupported_medium', mediaRefusal);
    }
    if (!_ble.allowsControlMedium(request.controlMedium, platform)) {
      throw PairingRejectException(
        'unsupported_medium',
        'BLE control not allowed on ${platform.name} '
        '(matrix=${_matrix.bleDiscovery(platform).name})',
      );
    }
    if (joined.containsKey(request.deviceId)) {
      throw PairingRejectException(
        'capacity',
        'device already joined: ${request.deviceId}',
      );
    }
    pending.removeWhere((item) => item.requestId == request.requestId);
    pending.add(request);
    return PairingAckStatus.pendingApproval;
  }

  /// AC-1.4: explicit director approval required before join.
  /// AC-1.6: multi-role sets gated by capability matrix in release builds.
  JoinedDevice approve({
    required String requestId,
    required MatrixPlatform platform,
    List<ProductionRole>? approvedRoles,
  }) {
    final index = pending.indexWhere((item) => item.requestId == requestId);
    if (index < 0) {
      throw StateError('no pending request $requestId');
    }
    final request = pending[index];
    final roles = approvedRoles ?? List<ProductionRole>.from(request.requestedRoles);
    if (roles.isEmpty) {
      throw ArgumentError('approved roles must not be empty');
    }
    try {
      RoleAssignment(
        matrix: _matrix,
        releaseBuild: _releaseBuild,
      ).assign(roles: roles, platform: platform);
    } on RoleAssignmentException catch (error) {
      throw PairingRejectException(error.reason, error.message);
    }
    pending.removeAt(index);
    final member = JoinedDevice(
      deviceId: request.deviceId,
      deviceLabel: request.deviceLabel,
      roles: roles,
      mediaMedium: request.mediaMedium,
      approvedByDirector: true,
    );
    joined[member.deviceId] = member;
    return member;
  }

  void reject({required String requestId, String reason = 'director_rejected'}) {
    final index = pending.indexWhere((item) => item.requestId == requestId);
    if (index < 0) {
      throw StateError('no pending request $requestId');
    }
    pending.removeAt(index);
  }

  bool isInSession(String deviceId) => joined.containsKey(deviceId);
}
