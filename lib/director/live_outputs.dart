// Multiple live outputs session control (OM-033 / G7 / AC-3.1).
// Each live aspect binds an independent layout to a raw stream destination.
// Social/OAuth publishing is out of scope (D8 / OM-034+). Crash recovery never
// auto-restarts streaming (AC-5.6 with OM-019).

import 'output_enablement.dart';

class LiveOutputDestination {
  const LiveOutputDestination({
    required this.aspect,
    required this.layoutId,
    required this.kind,
    required this.url,
    this.active = false,
  });

  final String aspect;
  final String layoutId;
  final String kind;
  final String url;
  final bool active;

  LiveOutputDestination copyWith({
    String? aspect,
    String? layoutId,
    String? kind,
    String? url,
    bool? active,
  }) {
    return LiveOutputDestination(
      aspect: aspect ?? this.aspect,
      layoutId: layoutId ?? this.layoutId,
      kind: kind ?? this.kind,
      url: url ?? this.url,
      active: active ?? this.active,
    );
  }

  Map<String, Object?> toWire() {
    return <String, Object?>{
      'aspect': aspect,
      'layoutId': layoutId,
      'kind': kind,
      'url': url,
      'active': active,
    };
  }

  static LiveOutputDestination fromWire(Map<Object?, Object?> wire) {
    return LiveOutputDestination(
      aspect: wire['aspect']?.toString() ?? '',
      layoutId: wire['layoutId']?.toString() ?? '',
      kind: wire['kind']?.toString() ?? 'file',
      url: wire['url']?.toString() ?? '',
      active: wire['active'] == true,
    );
  }
}

/// Default independent layout ids per aspect (never silent-fork).
const Map<String, String> defaultLiveLayoutIds = <String, String>{
  '16:9': 'live-16x9',
  '9:16': 'live-9x16',
  '1:1': 'live-1x1',
};

String defaultLiveDestinationUrl(String aspect) {
  final safe = aspect.replaceAll(':', 'x');
  return 'file:live_$safe.ts';
}

/// Applies live-output intent and crash recovery without auto-restart.
class LiveOutputsController {
  LiveOutputsController({List<LiveOutputDestination>? initial})
      : destinations = List<LiveOutputDestination>.from(
          initial ?? const <LiveOutputDestination>[],
        );

  List<LiveOutputDestination> destinations;

  bool get streaming => destinations.any((d) => d.active);

  Set<String> get activeAspects =>
      destinations.where((d) => d.active).map((d) => d.aspect).toSet();

  /// Build independent destinations for the selected live aspects.
  List<LiveOutputDestination> plan({
    required Iterable<String> liveAspects,
    Map<String, String>? layoutIds,
    Map<String, String>? urls,
  }) {
    final planned = <LiveOutputDestination>[];
    for (final aspect in liveAspects) {
      if (!outputAspects.contains(aspect)) {
        throw ArgumentError('unsupported live aspect: $aspect');
      }
      final layoutId =
          layoutIds?[aspect] ?? defaultLiveLayoutIds[aspect] ?? 'live-$aspect';
      final url = urls?[aspect] ?? defaultLiveDestinationUrl(aspect);
      planned.add(
        LiveOutputDestination(
          aspect: aspect,
          layoutId: layoutId,
          kind: url.startsWith('udp:') || url.startsWith('udp://')
              ? 'udp'
              : 'file',
          url: url,
          active: false,
        ),
      );
    }
    _assertIndependentLayouts(planned);
    return planned;
  }

  /// Start streaming to the planned destinations.
  List<LiveOutputDestination> start({
    required Iterable<String> liveAspects,
    Map<String, String>? layoutIds,
    Map<String, String>? urls,
  }) {
    destinations = plan(
      liveAspects: liveAspects,
      layoutIds: layoutIds,
      urls: urls,
    )
        .map((d) => d.copyWith(active: true))
        .toList(growable: false);
    return destinations;
  }

  /// Stop all live destinations; keep last plan for UI status.
  List<LiveOutputDestination> stop() {
    destinations = destinations
        .map((d) => d.copyWith(active: false))
        .toList(growable: false);
    return destinations;
  }

  /// Apply enablement selection to live destinations.
  List<LiveOutputDestination> applyIntent({
    required Iterable<String> liveAspects,
    Map<String, String>? layoutIds,
    Map<String, String>? urls,
  }) {
    final aspects = liveAspects.toSet();
    if (aspects.isEmpty) {
      return stop();
    }
    return start(
      liveAspects: aspects,
      layoutIds: layoutIds,
      urls: urls,
    );
  }

  /// AC-5.6: after crash, leave streaming stopped; never auto-restart.
  List<LiveOutputDestination> recoverStopped() {
    destinations = destinations
        .map((d) => d.copyWith(active: false))
        .toList(growable: false);
    return destinations;
  }

  void _assertIndependentLayouts(List<LiveOutputDestination> planned) {
    final ids = planned.map((d) => d.layoutId).toList();
    if (ids.toSet().length != ids.length) {
      throw StateError(
        'live outputs require independent layout_id values; silent forks are forbidden',
      );
    }
  }
}
