import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/capability_matrix.dart';
import 'package:open_matchday/role_assignment.dart';
import 'package:open_matchday/roles.dart';

void main() {
  test('all seven roles are individually assignable', () {
    final assignment = RoleAssignment(releaseBuild: true);
    expect(assignment.assignableRoles, hasLength(7));
    for (final role in allProductionRoles) {
      final result = assignment.assign(
        roles: [role],
        platform: MatrixPlatform.windows,
      );
      expect(result.roles, [role]);
      expect(assignment.canAssignSingle(role), isTrue);
    }
  });

  test('release builds gate unverified combinations', () {
    final assignment = RoleAssignment(releaseBuild: true);
    expect(
      () => assignment.assign(
        roles: const [
          ProductionRole.camera,
          ProductionRole.scoreboardReader,
        ],
        platform: MatrixPlatform.linux,
      ),
      throwsA(
        isA<RoleAssignmentException>().having(
          (error) => error.reason,
          'reason',
          'combination_gated',
        ),
      ),
    );
  });

  test('partial combination with limits is allowed in release', () {
    final matrix = CapabilityMatrix(
      roleCombinationOverrides: {
        'windows:camera+director': const CapabilityNote(
          state: CapabilityState.partial,
          limits: 'preview only; no Program cut on same device',
        ),
      },
    );
    final assignment = RoleAssignment(
      matrix: matrix,
      releaseBuild: true,
    );
    final result = assignment.assign(
      roles: const [ProductionRole.director, ProductionRole.camera],
      platform: MatrixPlatform.windows,
    );
    expect(result.combinationState, CapabilityState.partial);
    expect(result.combinationLimits, contains('preview only'));
    expect(result.roles.map((role) => role.id).toList(), [
      'camera',
      'director',
    ]);
  });

  test('non-release builds allow unverified combinations', () {
    final assignment = RoleAssignment(releaseBuild: false);
    final result = assignment.assign(
      roles: const [
        ProductionRole.graphicsOperator,
        ProductionRole.socialOperator,
      ],
      platform: MatrixPlatform.macos,
    );
    expect(result.roles, hasLength(2));
    expect(result.combinationState, CapabilityState.unverified);
  });
}
