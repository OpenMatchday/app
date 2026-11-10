import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/capability_matrix.dart';
import 'package:open_matchday/pairing/pairing_session.dart';
import 'package:open_matchday/pairing_page.dart';

void main() {
  testWidgets('pairing page exposes QR, manual IP, BLE, and approve gate',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final session = PairingSession(
      sessionId: 'sess-test',
      directorDeviceId: 'dir-test',
      idFactory: () => 'fixed-offer',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PairingPage(
          session: session,
          platform: MatrixPlatform.windows,
        ),
      ),
    );

    expect(find.text('Pairing'), findsOneWidget);
    expect(find.textContaining('Wi-Fi or Ethernet only'), findsWidgets);
    expect(find.text('QR'), findsOneWidget);
    expect(find.text('Manual IP'), findsOneWidget);
    expect(find.text('Start BLE discovery'), findsOneWidget);
    expect(find.text('Create offer'), findsOneWidget);

    await tester.tap(find.text('Create offer'));
    await tester.pumpAndSettle();
    expect(session.offers, hasLength(1));
    expect(find.textContaining('"control_medium":"qr"'), findsOneWidget);

    await tester.ensureVisible(find.text('Start BLE discovery'));
    await tester.tap(find.text('Start BLE discovery'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ble-discovery-status')), findsOneWidget);
    expect(find.textContaining('BLE status: blocked'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit join request'));
    await tester.tap(find.text('Submit join request'));
    await tester.pumpAndSettle();
    expect(session.pending, hasLength(1));
    expect(session.joined, isEmpty);

    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(session.joined, hasLength(1));
    expect(find.textContaining('approved_by_director=true'), findsOneWidget);
  });
}
