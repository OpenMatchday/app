// Layout document shapes aligned with protocol layout.json (0.1.0).
// Safe-area insets: SMPTE ST 2046-1:2009 (action 93%, title 90%).

const double snapStep = 0.01;
const double nudgeFine = 0.0025;
const double nudgeCoarse = 0.01;
const double actionSafeInset = 0.035;
const double titleSafeInset = 0.05;
const bool defaultAspectLock = true;

const List<String> layoutAspects = <String>['16:9', '9:16', '1:1'];

const List<String> layoutAnchors = <String>[
  'top_left',
  'top_center',
  'top_right',
  'center_left',
  'center',
  'center_right',
  'bottom_left',
  'bottom_center',
  'bottom_right',
];

enum ScoreboardSourceMode { graphic, liveCrop }

enum LayoutState { draft, applied }

class ScoreboardSource {
  const ScoreboardSource({
    required this.mode,
    this.cropRegionId,
  });

  final ScoreboardSourceMode mode;
  final String? cropRegionId;

  ScoreboardSource copyWith({
    ScoreboardSourceMode? mode,
    String? cropRegionId,
  }) {
    return ScoreboardSource(
      mode: mode ?? this.mode,
      cropRegionId: cropRegionId ?? this.cropRegionId,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mode': mode == ScoreboardSourceMode.graphic ? 'graphic' : 'live_crop',
      if (cropRegionId != null) 'crop_region_id': cropRegionId,
    };
  }
}

class LayoutItem {
  const LayoutItem({
    required this.itemId,
    required this.kind,
    required this.anchor,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.z,
    required this.aspectLock,
    this.templateId,
    this.scoreboardSource,
  });

  final String itemId;
  final String kind;
  final String anchor;
  final double x;
  final double y;
  final double w;
  final double h;
  final int z;
  final bool aspectLock;
  final String? templateId;
  final ScoreboardSource? scoreboardSource;

  LayoutItem copyWith({
    String? itemId,
    String? kind,
    String? anchor,
    double? x,
    double? y,
    double? w,
    double? h,
    int? z,
    bool? aspectLock,
    String? templateId,
    ScoreboardSource? scoreboardSource,
  }) {
    return LayoutItem(
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      anchor: anchor ?? this.anchor,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      z: z ?? this.z,
      aspectLock: aspectLock ?? this.aspectLock,
      templateId: templateId ?? this.templateId,
      scoreboardSource: scoreboardSource ?? this.scoreboardSource,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'item_id': itemId,
      'kind': kind,
      'anchor': anchor,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      'z': z,
      'aspect_lock': aspectLock,
      if (templateId != null) 'template_id': templateId,
      if (scoreboardSource != null)
        'scoreboard_source': scoreboardSource!.toJson(),
    };
  }
}

class LayoutDocument {
  const LayoutDocument({
    required this.layoutId,
    required this.aspect,
    required this.state,
    required this.items,
    this.outputId,
    this.presetName,
    this.sceneId,
  });

  final String layoutId;
  final String? outputId;
  final String aspect;
  final LayoutState state;
  final List<LayoutItem> items;
  final String? presetName;
  final String? sceneId;

  LayoutDocument copyWith({
    String? layoutId,
    String? outputId,
    String? aspect,
    LayoutState? state,
    List<LayoutItem>? items,
    String? presetName,
    String? sceneId,
    bool clearSceneId = false,
    bool clearPresetName = false,
  }) {
    return LayoutDocument(
      layoutId: layoutId ?? this.layoutId,
      outputId: outputId ?? this.outputId,
      aspect: aspect ?? this.aspect,
      state: state ?? this.state,
      items: items ?? this.items,
      presetName: clearPresetName ? null : (presetName ?? this.presetName),
      sceneId: clearSceneId ? null : (sceneId ?? this.sceneId),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'layout_id': layoutId,
      if (outputId != null) 'output_id': outputId,
      'aspect': aspect,
      'state': state == LayoutState.draft ? 'draft' : 'applied',
      'items': items.map((item) => item.toJson()).toList(),
      if (presetName != null) 'preset_name': presetName,
      if (sceneId != null) 'scene_id': sceneId,
    };
  }
}

class OutputLayoutBinding {
  OutputLayoutBinding({
    required this.outputId,
    required this.aspect,
    required this.draft,
    this.applied,
  });

  final String outputId;
  final String aspect;
  LayoutDocument draft;
  LayoutDocument? applied;
}

double clamp01(double n) => n.clamp(0.0, 1.0);

double round4(double n) => (n * 10000).round() / 10000;

double snapValue(double n, bool enabled) {
  if (!enabled) {
    return round4(n);
  }
  return round4((n / snapStep).round() * snapStep);
}

LayoutItem createScoreboardItem({
  required String itemId,
  double x = 0.02,
  double y = 0.02,
  double w = 0.28,
  double h = 0.12,
  int z = 10,
}) {
  return LayoutItem(
    itemId: itemId,
    kind: 'scoreboard',
    anchor: 'top_left',
    x: x,
    y: y,
    w: w,
    h: h,
    z: z,
    aspectLock: defaultAspectLock,
    scoreboardSource: const ScoreboardSource(mode: ScoreboardSourceMode.graphic),
  );
}

LayoutDocument createDraftLayout({
  required String layoutId,
  required String outputId,
  required String aspect,
  List<LayoutItem>? items,
  String? sceneId,
}) {
  if (!layoutAspects.contains(aspect)) {
    throw ArgumentError('unsupported aspect $aspect');
  }
  return LayoutDocument(
    layoutId: layoutId,
    outputId: outputId,
    aspect: aspect,
    state: LayoutState.draft,
    sceneId: sceneId,
    items: items ??
        <LayoutItem>[
          createScoreboardItem(itemId: '$layoutId-scoreboard'),
        ],
  );
}
