/// Production roles from PROJECT_SPEC.md. Combinations gated later (AC-1.6).
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
}

const List<ProductionRole> allProductionRoles = ProductionRole.values;
