import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/roles.dart';

void main() {
  test('all seven production roles are present with stable ids', () {
    expect(allProductionRoles, hasLength(7));
    expect(
      allProductionRoles.map((role) => role.id).toList(),
      [
        'director',
        'camera',
        'scoreboard_reader',
        'event_operator',
        'graphics_operator',
        'social_operator',
        'program_monitor',
      ],
    );
  });
}
