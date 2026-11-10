import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA-256 helpers matching `teams/scripts/lib/content-hash.mjs` (AC-9.5).
const String kHashAlgorithm = 'sha256';
const String kIntegrityFile = 'integrity.json';

String sha256HexBytes(List<int> bytes) => sha256.convert(bytes).toString();

String sha256HexFile(File file) => sha256HexBytes(file.readAsBytesSync());

bool isIntegrityRelativePath(String rel) =>
    rel == kIntegrityFile || rel.endsWith('/$kIntegrityFile');

List<String> listHashableRels(Directory packageDir) {
  final root = packageDir.path;
  final rels = <String>[];
  if (!packageDir.existsSync()) {
    return rels;
  }
  for (final entity in packageDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    var rel = entity.path.substring(root.length).replaceAll('\\', '/');
    if (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    if (rel.isEmpty || isIntegrityRelativePath(rel)) {
      continue;
    }
    rels.add(rel);
  }
  rels.sort();
  return rels;
}

class IntegrityFileEntry {
  const IntegrityFileEntry({required this.path, required this.sha256});

  final String path;
  final String sha256;

  Map<String, Object> toWire() => <String, Object>{
        'path': path,
        'sha256': sha256,
      };

  static IntegrityFileEntry fromWire(Map<String, Object?> wire) {
    return IntegrityFileEntry(
      path: wire['path']?.toString() ?? '',
      sha256: wire['sha256']?.toString() ?? '',
    );
  }
}

class IntegrityManifest {
  const IntegrityManifest({
    required this.schemaVersion,
    required this.packageId,
    required this.version,
    required this.algorithm,
    required this.contentHash,
    required this.files,
  });

  final String schemaVersion;
  final String packageId;
  final String version;
  final String algorithm;
  final String contentHash;
  final List<IntegrityFileEntry> files;

  Map<String, Object> toWire() => <String, Object>{
        'schema_version': schemaVersion,
        'package_id': packageId,
        'version': version,
        'algorithm': algorithm,
        'content_hash': contentHash,
        'files': files.map((f) => f.toWire()).toList(),
      };

  static IntegrityManifest fromWire(Map<String, Object?> wire) {
    final filesRaw = wire['files'];
    final files = <IntegrityFileEntry>[];
    if (filesRaw is List) {
      for (final item in filesRaw) {
        if (item is Map) {
          files.add(
            IntegrityFileEntry.fromWire(Map<String, Object?>.from(item)),
          );
        }
      }
    }
    return IntegrityManifest(
      schemaVersion: wire['schema_version']?.toString() ?? '',
      packageId: wire['package_id']?.toString() ?? '',
      version: wire['version']?.toString() ?? '',
      algorithm: wire['algorithm']?.toString() ?? '',
      contentHash: wire['content_hash']?.toString() ?? '',
      files: files,
    );
  }

  static IntegrityManifest? load(Directory packageDir) {
    final file = File('${packageDir.path}${Platform.pathSeparator}$kIntegrityFile');
    if (!file.existsSync()) {
      return null;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw FormatException('integrity.json is not an object');
    }
    return IntegrityManifest.fromWire(Map<String, Object?>.from(decoded));
  }
}

class PackageIntegrityResult {
  const PackageIntegrityResult({
    required this.ok,
    required this.errors,
    this.computed,
  });

  final bool ok;
  final List<String> errors;
  final IntegrityManifest? computed;
}

IntegrityManifest computePackageIntegrity(Directory packageDir) {
  final rels = listHashableRels(packageDir);
  final files = <IntegrityFileEntry>[];
  final buffer = StringBuffer();
  for (final rel in rels) {
    final file = File(
      '${packageDir.path}${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}',
    );
    final digest = sha256HexFile(file);
    files.add(IntegrityFileEntry(path: rel, sha256: digest));
    buffer.write('$rel\x00$digest\n');
  }
  final contentHash = sha256HexBytes(utf8.encode(buffer.toString()));
  String packageId = '';
  String version = '';
  final manifestFile = File(
    '${packageDir.path}${Platform.pathSeparator}manifest.json',
  );
  if (manifestFile.existsSync()) {
    final decoded = jsonDecode(manifestFile.readAsStringSync());
    if (decoded is Map) {
      packageId = decoded['package_id']?.toString() ?? '';
      version = decoded['version']?.toString() ?? '';
    }
  }
  return IntegrityManifest(
    schemaVersion: '0.1.0',
    packageId: packageId,
    version: version,
    algorithm: kHashAlgorithm,
    contentHash: contentHash,
    files: files,
  );
}

PackageIntegrityResult verifyPackageIntegrity(
  Directory packageDir,
  IntegrityManifest expected,
) {
  final errors = <String>[];
  if (expected.algorithm != kHashAlgorithm) {
    errors.add('unsupported algorithm ${expected.algorithm}');
  }
  final computed = computePackageIntegrity(packageDir);
  if (expected.packageId.isNotEmpty &&
      expected.packageId != computed.packageId) {
    errors.add(
      'package_id mismatch: expected ${expected.packageId} got ${computed.packageId}',
    );
  }
  if (expected.version.isNotEmpty && expected.version != computed.version) {
    errors.add(
      'version mismatch: expected ${expected.version} got ${computed.version}',
    );
  }
  final expectedByPath = <String, String>{
    for (final f in expected.files) f.path: f.sha256,
  };
  for (final f in computed.files) {
    final want = expectedByPath.remove(f.path);
    if (want == null) {
      errors.add('unexpected file ${f.path}');
      continue;
    }
    if (want != f.sha256) {
      errors.add('file hash mismatch ${f.path}');
    }
  }
  for (final path in expectedByPath.keys) {
    errors.add('missing file $path');
  }
  if (expected.contentHash != computed.contentHash) {
    errors.add('content_hash mismatch');
  }
  return PackageIntegrityResult(
    ok: errors.isEmpty,
    errors: errors,
    computed: computed,
  );
}
