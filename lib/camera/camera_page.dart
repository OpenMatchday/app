import 'package:flutter/material.dart';

import '../design/brand_tokens.dart';
import '../design/open_matchday_theme.dart';
import 'tally.dart';

/// Camera role shell with unmistakable Program tally (AC-2.3).
class CameraPage extends StatelessWidget {
  const CameraPage({
    super.key,
    required this.tally,
  });

  final CameraTally tally;

  @override
  Widget build(BuildContext context) {
    final onAir = tally.isOnAir;
    return Theme(
      data: openMatchdayCameraDaylightTheme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Camera ${tally.cameraSourceId}'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tally',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When this camera is on Program, the tally indicator turns on. '
                    'Tally is unmistakable and never decorative (AC-2.3).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: onAir
                        ? 'Tally on air for ${tally.cameraSourceId}'
                        : 'Tally off for ${tally.cameraSourceId}',
                    child: Container(
                      key: const Key('camera-tally'),
                      constraints: const BoxConstraints(
                        minHeight: BrandTokens.tallyMinHeightPx,
                      ),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: onAir
                            ? BrandTokens.tallyOnAirBg
                            : BrandTokens.tallyOffBg,
                        border: Border.all(
                          color: onAir
                              ? BrandTokens.tallyOnAirBorder
                              : BrandTokens.tallyOffBorder,
                          width: onAir ? 4 : 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          key: const Key('camera-tally-label'),
                          onAir
                              ? BrandTokens.tallyLabelOn
                              : BrandTokens.tallyLabelOff,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: onAir
                                    ? BrandTokens.tallyOnAirText
                                    : BrandTokens.tallyOffText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    key: const Key('camera-program-source'),
                    onAir
                        ? 'Program source: ${tally.programSourceId}'
                        : tally.programSourceId.isEmpty
                            ? 'Program source: none'
                            : 'Program source: ${tally.programSourceId} (other camera)',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
