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

/// BLE, roles, role-combination, and output-combination gates from ARCHITECTURE.md.
class CapabilityMatrix {
  const CapabilityMatrix({
    this.bleByPlatform,
    this.roleCombinationOverrides,
    this.aspectSupportOverrides,
    this.recordingSupportOverrides,
    this.outputCombinationOverrides,
  });

  final Map<MatrixPlatform, CapabilityState>? bleByPlatform;
  final Map<String, CapabilityNote>? roleCombinationOverrides;

  /// Key: `$platform:$aspect` where aspect is `16:9` / `9:16` / `1:1`.
  final Map<String, CapabilityNote>? aspectSupportOverrides;

  /// Key: platform name.
  final Map<String, CapabilityNote>? recordingSupportOverrides;

  /// Key: `$platform:$combinationKey` (see [outputCombinationKey]).
  final Map<String, CapabilityNote>? outputCombinationOverrides;

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

  /// Per-aspect live-output support flag (AC-3.1). Defaults unverified.
  CapabilityNote aspectSupport(String aspect, MatrixPlatform platform) {
    final key = '${platform.name}:$aspect';
    return aspectSupportOverrides?[key] ??
        const CapabilityNote(state: CapabilityState.unverified);
  }

  /// Recording support flag for director device class (AC-3.1). Defaults unverified.
  CapabilityNote recordingSupport(MatrixPlatform platform) {
    return recordingSupportOverrides?[platform.name] ??
        const CapabilityNote(state: CapabilityState.unverified);
  }

  /// Stable key for recording + live aspects (order-independent aspects).
  static String outputCombinationKey({
    required bool recording,
    required Iterable<String> liveAspects,
  }) {
    final aspects = liveAspects.toSet().toList()..sort();
    final parts = <String>[
      if (recording) 'recording',
      ...aspects,
    ];
    if (parts.isEmpty) {
      return 'none';
    }
    return parts.join('+');
  }

  /// Combination cell for recording + N live aspects (AC-3.11 / G7).
  /// Defaults to unverified until director-class sustain is measured.
  CapabilityNote outputCombination({
    required bool recording,
    required Iterable<String> liveAspects,
    required MatrixPlatform platform,
  }) {
    final aspects = liveAspects.toSet();
    if (!recording && aspects.isEmpty) {
      return const CapabilityNote(state: CapabilityState.verified);
    }
    final key =
        '${platform.name}:${outputCombinationKey(recording: recording, liveAspects: aspects)}';
    return outputCombinationOverrides?[key] ??
        const CapabilityNote(state: CapabilityState.unverified);
  }

  bool _noteAllows(CapabilityNote note) {
    return note.state == CapabilityState.verified ||
        note.state == CapabilityState.partial;
  }

  /// AC-3.1 / AC-3.11: release enables only measured aspect flags + combination.
  bool allowsOutputCombination({
    required bool recording,
    required Iterable<String> liveAspects,
    required MatrixPlatform platform,
    required bool releaseBuild,
  }) {
    final aspects = liveAspects.toSet();
    if (!recording && aspects.isEmpty) {
      return true;
    }
    if (!releaseBuild) {
      // Non-release builds may enable combinations for measurement; matrix
      // state remains visible via [outputCombination] / [aspectSupport].
      return true;
    }
    if (recording && !_noteAllows(recordingSupport(platform))) {
      return false;
    }
    for (final aspect in aspects) {
      if (!_noteAllows(aspectSupport(aspect, platform))) {
        return false;
      }
    }
    return _noteAllows(
      outputCombination(
        recording: recording,
        liveAspects: aspects,
        platform: platform,
      ),
    );
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
