import 'roles.dart';

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

/// Documented limit when a cell is [CapabilityState.partial].
class CapabilityNote {
  const CapabilityNote({
    required this.state,
    this.limits,
  });

  final CapabilityState state;
  final String? limits;
}

/// BLE, roles, and role-combination gates from ARCHITECTURE.md.
class CapabilityMatrix {
  const CapabilityMatrix({
    this.bleByPlatform,
    this.roleCombinationOverrides,
  });

  final Map<MatrixPlatform, CapabilityState>? bleByPlatform;
  final Map<String, CapabilityNote>? roleCombinationOverrides;

  /// Mirrors ARCHITECTURE.md row "BLE discovery/control".
  CapabilityState bleDiscovery(MatrixPlatform platform) {
    return bleByPlatform?[platform] ?? CapabilityState.unverified;
  }

  bool allowsBleControl(MatrixPlatform platform) {
    final state = bleDiscovery(platform);
    return state == CapabilityState.verified ||
        state == CapabilityState.partial;
  }

  /// Single-role cell (ARCHITECTURE.md role rows). All start unverified.
  CapabilityState roleCapability(
    ProductionRole role,
    MatrixPlatform platform,
  ) {
    return CapabilityState.unverified;
  }

  /// Stable key for a role set (order-independent).
  static String combinationKey(Iterable<ProductionRole> roles) {
    final ids = roles.map((role) => role.id).toList()..sort();
    return ids.join('+');
  }

  /// Combination cell for two or more roles on one device (AC-1.6).
  /// Defaults to unverified until OM-046 / measurement notes land.
  CapabilityNote roleCombination(
    Iterable<ProductionRole> roles,
    MatrixPlatform platform,
  ) {
    final unique = roles.toSet();
    if (unique.length < 2) {
      return const CapabilityNote(state: CapabilityState.verified);
    }
    final key = '${platform.name}:${combinationKey(unique)}';
    return roleCombinationOverrides?[key] ??
        const CapabilityNote(state: CapabilityState.unverified);
  }

  /// AC-1.6: combinations enabled only when verified or partial.
  bool allowsRoleCombination(
    Iterable<ProductionRole> roles,
    MatrixPlatform platform, {
    required bool releaseBuild,
  }) {
    final unique = roles.toSet();
    if (unique.isEmpty) {
      return false;
    }
    if (unique.length == 1) {
      return true;
    }
    final note = roleCombination(unique, platform);
    final allowed = note.state == CapabilityState.verified ||
        note.state == CapabilityState.partial;
    if (!releaseBuild) {
      // Non-release builds may select combinations for measurement, but the
      // gate still reports matrix state via [roleCombination].
      return true;
    }
    return allowed;
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
