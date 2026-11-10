import 'package:flutter/foundation.dart' show kReleaseMode;

import 'capability_matrix.dart';
import 'roles.dart';

class RoleAssignmentException implements Exception {
  RoleAssignmentException(this.reason, this.message);

  final String reason;
  final String message;

  @override
  String toString() => message;
}

class RoleAssignmentResult {
  const RoleAssignmentResult({
    required this.roles,
    required this.platform,
    required this.combinationState,
    this.combinationLimits,
    required this.releaseGated,
  });

  final List<ProductionRole> roles;
  final MatrixPlatform platform;
  final CapabilityState combinationState;
  final String? combinationLimits;
  final bool releaseGated;
}

/// Assigns one or more production roles with AC-1.5 / AC-1.6 gates.
class RoleAssignment {
  RoleAssignment({
    this.matrix = const CapabilityMatrix(),
    bool? releaseBuild,
  }) : releaseBuild = releaseBuild ?? kReleaseMode;

  final CapabilityMatrix matrix;
  final bool releaseBuild;

  /// AC-1.5: every production role is individually assignable.
  bool canAssignSingle(ProductionRole role) => true;

  List<ProductionRole> get assignableRoles =>
      List<ProductionRole>.unmodifiable(allProductionRoles);

  /// Apply a role set for this device. Empty set clears assignment.
  RoleAssignmentResult assign({
    required Iterable<ProductionRole> roles,
    required MatrixPlatform platform,
  }) {
    final unique = <ProductionRole>{...roles}.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (unique.isEmpty) {
      return RoleAssignmentResult(
        roles: const [],
        platform: platform,
        combinationState: CapabilityState.verified,
        releaseGated: releaseBuild,
      );
    }
    for (final role in unique) {
      if (!canAssignSingle(role)) {
        throw RoleAssignmentException(
          'role_unavailable',
          'Role ${role.label} is not assignable',
        );
      }
    }
    if (!matrix.allowsRoleCombination(
      unique,
      platform,
      releaseBuild: releaseBuild,
    )) {
      final note = matrix.roleCombination(unique, platform);
      throw RoleAssignmentException(
        'combination_gated',
        'Role combination '
        '${CapabilityMatrix.combinationKey(unique)} '
        'is ${note.state.name} on ${platform.name} and cannot be enabled '
        'in release builds (AC-1.6)'
        '${note.limits == null ? '' : '; limits: ${note.limits}'}',
      );
    }
    final note = matrix.roleCombination(unique, platform);
    return RoleAssignmentResult(
      roles: unique,
      platform: platform,
      combinationState: note.state,
      combinationLimits: note.limits,
      releaseGated: releaseBuild,
    );
  }
}
