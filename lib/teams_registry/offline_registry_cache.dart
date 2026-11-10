import 'dart:io';

import 'content_hash.dart';

/// Result of attempting to install a candidate registry package (AC-9.5).
class CacheInstallResult {
  const CacheInstallResult({
    required this.installed,
    required this.keptLastGood,
    required this.message,
    this.contentHash,
    this.errors = const <String>[],
  });

  final bool installed;
  final bool keptLastGood;
  final String message;
  final String? contentHash;
  final List<String> errors;
}

/// Integrity-checked offline teams registry cache with last-good retention.
///
/// Layout under [root]:
/// - `current/` — active verified package
/// - `last_good/` — previous verified package retained on failed updates
class OfflineRegistryCache {
  OfflineRegistryCache({required this.root});

  final Directory root;

  Directory get currentDir =>
      Directory('${root.path}${Platform.pathSeparator}current');

  Directory get lastGoodDir =>
      Directory('${root.path}${Platform.pathSeparator}last_good');

  bool get hasCurrent =>
      currentDir.existsSync() &&
      File('${currentDir.path}${Platform.pathSeparator}manifest.json')
          .existsSync();

  bool get hasLastGood =>
      lastGoodDir.existsSync() &&
      File('${lastGoodDir.path}${Platform.pathSeparator}manifest.json')
          .existsSync();

  /// Active package directory: verified current, else last-good.
  Directory? get activePackageDir {
    if (hasCurrent) {
      final manifest = IntegrityManifest.load(currentDir);
      if (manifest != null) {
        final check = verifyPackageIntegrity(currentDir, manifest);
        if (check.ok) {
          return currentDir;
        }
      }
    }
    if (hasLastGood) {
      final manifest = IntegrityManifest.load(lastGoodDir);
      if (manifest != null) {
        final check = verifyPackageIntegrity(lastGoodDir, manifest);
        if (check.ok) {
          return lastGoodDir;
        }
      }
    }
    return null;
  }

  /// Install [candidateDir] only when integrity verifies.
  /// On failure, keep existing current/last-good unchanged.
  CacheInstallResult installCandidate(Directory candidateDir) {
    final manifest = IntegrityManifest.load(candidateDir);
    if (manifest == null) {
      return CacheInstallResult(
        installed: false,
        keptLastGood: hasCurrent || hasLastGood,
        message: 'candidate missing $kIntegrityFile',
        errors: <String>['missing integrity.json'],
      );
    }
    final check = verifyPackageIntegrity(candidateDir, manifest);
    if (!check.ok) {
      return CacheInstallResult(
        installed: false,
        keptLastGood: hasCurrent || hasLastGood,
        message: 'integrity check failed; last-good retained',
        contentHash: manifest.contentHash,
        errors: check.errors,
      );
    }

    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }

    if (hasCurrent) {
      _replaceDir(from: currentDir, to: lastGoodDir);
    }

    _copyPackage(from: candidateDir, to: currentDir);

    return CacheInstallResult(
      installed: true,
      keptLastGood: hasLastGood,
      message: 'installed verified package',
      contentHash: manifest.contentHash,
    );
  }

  void _replaceDir({required Directory from, required Directory to}) {
    if (to.existsSync()) {
      to.deleteSync(recursive: true);
    }
    // Prefer rename; fall back to copy+delete across volumes.
    try {
      from.renameSync(to.path);
    } on FileSystemException {
      _copyPackage(from: from, to: to);
      from.deleteSync(recursive: true);
    }
  }

  void _copyPackage({required Directory from, required Directory to}) {
    if (to.existsSync()) {
      to.deleteSync(recursive: true);
    }
    to.createSync(recursive: true);
    for (final entity in from.listSync(recursive: true, followLinks: false)) {
      final rel = entity.path
          .substring(from.path.length)
          .replaceAll('\\', '/');
      final cleaned = rel.startsWith('/') ? rel.substring(1) : rel;
      final destPath =
          '${to.path}${Platform.pathSeparator}${cleaned.replaceAll('/', Platform.pathSeparator)}';
      if (entity is Directory) {
        Directory(destPath).createSync(recursive: true);
        continue;
      }
      if (entity is File) {
        final parent = File(destPath).parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }
        entity.copySync(destPath);
      }
    }
  }
}
