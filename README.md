# Open Matchday -- app

Shared Open Matchday application: role shells and event management.

Part of the [OpenMatchday](https://github.com/OpenMatchday) organization.

## D1 status

Provisional framework: **Flutter** + native media modules (see sibling `docs` spike `spikes/d1-application-framework.md` and root `ARCHITECTURE.md` decision D1).

## D5 OCR (Scoreboard Reader)

Provisional engine lives in sibling `media` (Tesseract 5 + tessdata_fast eng, Apache-2.0). The Flutter app consumes OCR readings (value, confidence, timestamp, staleness) through the media native bridge — it does not embed an OCR engine in Dart. Spike record: `docs/spikes/d5-ocr-engine.md` and `ARCHITECTURE.md` decision D5.

## Pairing (OM-011 / AC-1.1–AC-1.4)

- QR and manual IP control pairing are always available.
- BLE discovery/control runs only when ARCHITECTURE.md capability matrix allows (currently unverified on all platforms — discovery stays blocked).
- Media start refuses cellular and BLE; Wi-Fi/Ethernet only (see sibling `media/gates`).
- Devices stay pending until the director explicitly approves.

## Director Preview (OM-013 / AC-2.1) and audio (OM-014 / AC-2.4–2.5)

- Director page exposes distinct **Preview** and **Program** buses; only Program feeds outputs.
- Two camera sources (`cam-1`, `cam-2`) are selectable for Preview.
- Audio source is selectable independently of Preview/Program video; peak/RMS meters are visible.
- Preview start/stop via `MediaBridge.startPreview` (Wi-Fi/Ethernet only); audio via `selectAudioSource` / `readAudioMeters`.
- Capture/encode/SRT dual-path + audio meter measurements live in sibling `media` (`preview/`, `measurements/`).

## A/V sync (OM-016 / AC-2.6)

- Director exposes an A/V sync monitor and drift-correction action.
- `MediaBridge.readAvSync` / `applyDriftCorrection` talk to the media plane; measured G5 numbers live in sibling `media/measurements/results/g5_av_sync_*.json`.

## Connection health (OM-017 / AC-2.7 / AC-2.8)

- Director shows per-source health (`connected` / `degraded` / `lost`) with timestamps.
- Source-loss fallback modes: last frame freeze, slate, alternate source; session stays alive.
- `MediaBridge.readSourceHealth` / `applySourceLossFallback`; drop measurements in sibling `media/measurements/results/om017_source_health_*.json`.

## Layout editor (OM-025 / AC-3.2–3.10)

- Graphics Operator layout editor: per-output draft layouts, exact-output preview, drag/numeric resize, aspect lock, anchors, z-order, snap, SMPTE ST 2046-1 safe areas, nudge, undo/redo, presets, draft-vs-apply, graphic/live_crop scoreboard source.
- Authoritative geometry model lives in sibling `graphics` (`src/layout-editor.mjs`); Flutter store mirrors it for interactive UI.

## Lineups (OM-029 / AC-7.1–7.6)

- Lineup operator shell: starters vs substitutes, captain/GK markers, photo focal metadata, reduced-motion toggle.
- Take to Program is refused until the current draft revision has been previewed (AC-7.6).
- Geometry SVG renderer lives in sibling `graphics` (`src/lineup.mjs`) using sports package field/formation data.

## Scoreboard OCR + camera-move (OM-031 / AC-4.7, AC-5.2, AC-5.4)

- Readings carry value, calibrated confidence, timestamp, staleness.
- Confidence: Tesseract TSV conf/100 when >0, else digit-parse quality; authority gate `minConfidence=0.7`.
- Camera-move probe marks readings and live crops stale and invalidates calibration until recalibrated.
- `ScoreboardOcrStore` + `MediaBridge.probeCameraMove` / `readOcrRegion`; media harness `preview/run_ocr_regions.py`.

## Scoreboard calibration (OM-030 / AC-4.1–4.6)

- Scoreboard Reader shell: freeze preview, mark TL/TR/BR/BL with zoom + handles, validate geometry, confirm rectified board, define OCR regions.
- Sport field allowlists omit absent fields (no faked shot clock on futsal / basketball youth).
- Normalized corner storage reprojects across preview scale, rotation, and resolution (AC-4.6).
- Media-side freeze/rectify harness: sibling `media/preview/run_calibration.py`.

## Output enablement (OM-026 / AC-3.1 / AC-3.11 / G7)

- Director Outputs panel: recording + live `16:9` / `9:16` / `1:1` with capability-matrix gates.
- Release builds enable a combination only after aspect support flags and the combination cell are verified or partial from director-class sustain measurements.
- Non-release builds may enable unverified combinations for measurement; `MediaBridge.setOutputIntents` records recording/streaming intent.
- Media sustain harness: sibling `media/preview/run_output_combination.py`.

## Recording (OM-032 / G6 / AC-3.1)

- Applying recording enablement starts a recording session path via `MediaBridge.setOutputIntents`; clearing it stops the session.
- Crash recovery (`recoverOutputsStopped` + `RecordingController.recoverStopped`) leaves recording stopped (AC-5.6).
- File encode/playback measured in sibling `media/preview/run_recording.py` (G6).

## Multiple live outputs (OM-033 / G7 / AC-3.1)

- Enabled live aspects each bind an independent layout id to a raw stream destination (`LiveOutputsController`).
- `MediaBridge.setOutputIntents` carries `liveAspects` + `liveOutputs`; crash recovery leaves streaming stopped.
- Social Operator: five offline templates (announcement/lineup/score/result/clip), local export with `account=null`, no engagement metrics (AC-11.3/11.4/11.7). Official-API publish adapters in sibling `social` (OM-035). Connected accounts screen (OM-036) uses only the `social_connections` credential plane and shows provider, capabilities, status, revoke (AC-11.1/11.2).

## Develop

Requires Flutter stable (spike verified on 3.47.9).

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build apk
```

## License

MIT. See [LICENSE](LICENSE). Flutter SDK is BSD 3-Clause (upstream).
