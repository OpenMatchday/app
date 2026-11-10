/// Production roles from PROJECT_SPEC.md. Combinations gated by AC-1.6.
enum ProductionRole {
  director,
  camera,
  scoreboardReader,
  eventOperator,
  graphicsOperator,
  socialOperator,
  programMonitor,
}

extension ProductionRoleLabel on ProductionRole {
  String get id => switch (this) {
        ProductionRole.director => 'director',
        ProductionRole.camera => 'camera',
        ProductionRole.scoreboardReader => 'scoreboard_reader',
        ProductionRole.eventOperator => 'event_operator',
        ProductionRole.graphicsOperator => 'graphics_operator',
        ProductionRole.socialOperator => 'social_operator',
        ProductionRole.programMonitor => 'program_monitor',
      };

  String get label => switch (this) {
        ProductionRole.director => 'Director',
        ProductionRole.camera => 'Camera',
        ProductionRole.scoreboardReader => 'Scoreboard Reader',
        ProductionRole.eventOperator => 'Event Operator',
        ProductionRole.graphicsOperator => 'Graphics Operator',
        ProductionRole.socialOperator => 'Social Operator',
        ProductionRole.programMonitor => 'Program Monitor',
      };

  String get responsibility => switch (this) {
        ProductionRole.director =>
          'Approves devices; Preview/Program; Cut/Take; output enablement; audio source; health',
        ProductionRole.camera => 'Capture and send media; receive tally',
        ProductionRole.scoreboardReader =>
          'Calibrated board capture; OCR readings',
        ProductionRole.eventOperator =>
          'Clocks, scores, period/fouls, authority confirms',
        ProductionRole.graphicsOperator =>
          'Scenes, templates, themes, layout drafts',
        ProductionRole.socialOperator =>
          'Templates, drafts, export, approved publishing',
        ProductionRole.programMonitor =>
          'View Program (and optionally Preview) without control',
      };
}

const List<ProductionRole> allProductionRoles = ProductionRole.values;
